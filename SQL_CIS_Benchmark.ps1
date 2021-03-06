######################################################
#                                                    #
#  CIS Microsoft SQL Server 2014 Benchmark (v1.2.0)  #
#                                                    #
#                Written by Ian Guile                #
#                                                    #
######################################################
#02022021 - PD - Got this script working on SQl 2019 version; it should be used as an algorithem templete instead of fix all code. 
#Its just technical refactoring to get it execute without errors.

$Fix_Allowed = 0

 
# 2.01 - 2.08 & 5.2
function S-Name_Conf_InUse.F-SysConf ($name, $fix = $name, $PreQ = "", $Value = 0) {

    $QueryResults = @(Invoke-Sqlcmd -Query "$PreQ SELECT name, CAST(value as int) as configured, CAST(value_in_use as int) as in_use FROM sys.configurations
        WHERE name = $name;")
    if ($QueryResults.configured -ne $Value -or $QueryResults.in_use -ne $Value) {
        Write-host("$name enabled. +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "EXECUTE sp_configure $fix, $Value;`nRECONFIGURE;"
            $UserInput = Read-Host("`tDisable by running the following? [Y/n]`n$Query`n")
            if ($UserInput -Notmatch "n") {
                Invoke-Sqlcmd -Query $Query
                Write-Host("$name disabled. +1")
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host("$($name) disabled. +1")
        return 1
    }
}

# 2.09
function RemoteAdminConnection () {
    $Q1 = "SELECT name FROM sys.databases WHERE is_trustworthy_on = 1
        AND name != 'msdb' AND state = 0;"
    $QueryResults = @(Invoke-Sqlcmd -Query $Q1)
    if ($QueryResults.name) {
        Write-Host("Trustworthy databases found +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER DATABASE <database> SET TRUSTWORTHY OFF;"
            $UserInput = Read-Host("The following trustworthy databases were found.`n$($QueryResults.name)`n
    Untrust all databases by running the following? [Y/n]`n$Query`n")
            if ($UserInput -Notmatch "n") {
                foreach ($db in $QueryResults.name) {
                    Invoke-Sqlcmd -Query $Query.Replace("<database>", $db)
                }
                Write-Host("All databases untrusted +1")
                return 1
            }
            else {
                $UserInput = Read-Host("Untrust some databases? [Y/n]")
                if ($UserInput -Notmatch "n") {
                    foreach ($db in $QueryResults.name) {
                        $UserInput = Read-Host("Untrust $($db)? [Y/n]")
                        if ($UserInput -Notmatch "n") {
                            Invoke-Sqlcmd -Query $Query.Replace("<database>", $db)
                        }
                    }
                }
                $QueryResults = @(Invoke-Sqlcmd -Query $Q1)
                if ($QueryResults.name) { return 0 }
                Write-Host("All databases untrusted +1")
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host("No trustworthy databases found +1")
        return 1
    }
}

# 2.12
function HideInstance {
    $QueryResults = @(Invoke-Sqlcmd -Query "DECLARE @getValue INT;
        EXEC master..xp_instance_regread
            @rootkey = N'HKEY LOCAL MACHINE',
            @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
            @value_name = N'HideInstance',
            @value = @getValue OUTPUT;
        SELECT @getValue;")
    if ($QueryResults -eq 1) {
        Write-Host("Instances not hidden +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "EXEC master..xp instance regwrite`n`t@rootkey = N'HKEY LOCAL MACHINE',
    @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
    @value_name = N'HideInstance',`n`t@type = N'REG_DWORD',`n`t@value = 1;"
            $UserInput = Read-Host("Hide instance by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                Invoke-Sqlcmd -Query $Query
                Write-Host("Instances hidden +1")
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host("Instances hidden +1")
        return 1
    }
}

# 2.13 - 2.14
function saDisabled_Renamed {
    $saScore = @(0, 0)
    $QueryResults = @(Invoke-Sqlcmd -Query "SELECT name, CAST(is_disabled as int) as is_disabled
        FROM sys.server_principals
        WHERE sid = 0x1;")
    if ($QueryResults.is_disabled -eq 0) {
        Write-Host("'sa' login enabled +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER LOGIN $($QueryResults.name) DISABLE;"
            $UserInput = Read-Host("Disabled 'sa' login by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                Invoke-Sqlcmd -Query $Query
                Write-Host("'sa' login disabled +1")
                $saScore[0] = 1
            }
        }
    }
    else {
        Write-Host("'sa' login disabled +1")
        $saScore[0] = 1
    }
    if ($QueryResults.name -eq "sa") {
        Write-Host("'sa' account not renamed +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER LOGIN $($QueryResults.name) WITH NAME = <chosen name>;"
            $UserInput = Read-Host("Change 'sa' account name by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                $UserInput = Read-Host("What new name should be used for the account?")
                Invoke-Sqlcmd -Query "ALTER LOGIN $($QueryResults.name) WITH NAME = $($UserInput);"
                Write-Host("'sa' account renamed +1")
                $saScore[1] = 1
            }
        }
    }
    else {
        Write-Host("'sa' account renamed +1")
        $saScore[1] = 1
    }
    return $saScore
}

# 2.15
function xp_cmdshell {
    $QueryResults = @(Invoke-Sqlcmd -Query "RECONFIGURE WITH OVERRIDE;
        EXECUTE sp_configure 'xp_cmdshell';")
    if ($QueryResults.config_value -ne 0 -or $QueryResults.run_value -ne 0) {
        Write-Host("xp_cmdshell enabled +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "EXECUTE sp_configure 'xp_cmdshell', 0;`nRECONFIGURE;"
            $UserInput = Read-Host("disable xp_cmdshell by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                Invoke-Sqlcmd -Query $Query
                Write-Host("xp_cmdshell disabled +1")
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host("xp_cmdshell disabled +1")
        return 1
    }
}

# 2.16
function Contained_AutoClose {
    $Q1 = "SELECT name, containment, containment_desc, is_auto_close_on
        FROM sys.databases WHERE containment <> 0 AND is_auto_close_on = 1"
    $R1 = "no contained databases with 'AUTO_CLOSE' found +1"
    $QueryResults = @(Invoke-Sqlcmd $Q1)
    if ($QueryResults.name) {
        Write-Host(($R1.Replace("0","1")).Replace("no ", ""))
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER DATABASE <database> SET AUTO_CLOSE OFF;"
            $UserInput = Read-Host("The following contained databases with 'AUTO_CLOSE' were found.`n$($QueryResults.name)`n
    disable 'AUTO_CLOSE' on all databases by running the following? [Y/n]`n$Query`n")
            if ($UserInput -Notmatch "n") {
                foreach ($db in $QueryResults.name) {
                    Invoke-Sqlcmd -Query $Query.Replace("<database>", $db)
                }
                Write-Host($R1.Replace("found ", ""))
                return 1
            }
            else { 
                $UserInput = Read-Host("Disable 'AUTO_CLOSE' on some contained databases? [Y/n]")
                if ($UserInput -Notmatch "n") {
                    foreach ($db in $QueryResults.name) {
                        $UserInput = Read-Host("Untrust $($database)? [Y/n]")
                        if ($UserInput -Notmatch "n") {
                            Invoke-Sqlcmd -Query $Query.Replace("<database>", $db)
                        }
                    }
                }
                $QueryResults = @(Invoke-Sqlcmd $Q1)
                if ($QueryResults.name) { return 0 }
                Write-Host($R1.Replace("found ", ""))
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host($R1)
        return 1
    }
}

# 2.17
function NosaAccount{
    $QueryResults = @(Invoke-Sqlcmd -Query "SELECT sid, name
        FROM sys.server_principals
        WHERE name = 'sa'
        AND sid <> 0x01;")
    if ($QueryResults.name) {
        Write-Host("'sa' account name found +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER LOGIN sa WITH NAME = <chosen name>;"
            $UserInput = Read-Host("Change 'sa' account name by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                $UserInput = Read-Host("What new name should be used for the account?")
                Invoke-Sqlcmd -Query "ALTER LOGIN sa WITH NAME = $($UserInput);"
                Write-Host("account renamed, no user with name 'sa' +1")
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host("no user with name 'sa' +1")
        return 1
    }
}

# 3.1
function ServerAuthentication {
    $QueryResults = @(Invoke-Sqlcmd -Query "SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS value;")
    if ($QueryResults.value -ne 1) {
        Write-Host("Multiple Authentication Methods used +0")
        if ($Fix_Allowed -eq 1) {
            Write-Host("Follow the following steps:
    1. Open the SQL Server Management Studio
    2. Open the Object Explorer tab and connect to the target database instance
    3. Right click the instance name and select 'Properties'
    4. Select the Security page from the left menu
    5. Set the Server authentication setting to 'Windows Authentication mode'")
        }
        return 0
    }
    else {
        Write-Host("Windows Authentication used +1")
        return 1
    }
}

# 3.2
function GuestConnect {
    $DBList = @(Invoke-Sqlcmd -Query "SELECT name FROM master.dbo.sysdatabases
        WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')")
    $Q1 = "USE <database>; `nGO`nSELECT DB_NAME() AS DBName, dpr.name, dpe.permission_name
            FROM sys.database_permissions dpe JOIN sys.database_principals dpr
            ON dpe.grantee_principal_id=dpr.principal_id
            WHERE dpr.name='guest' AND dpe.permission_name='CONNECT'"
    $R1 = "no databases found where 'guest' user has CONNECT ability +1"
    foreach ($db in $DBList) {
    write-host $Q1.Replace("<database>", $db.name)
        if (-Not (Invoke-Sqlcmd -Query $Q1.Replace("<database>", $db.name)).DBName) {
            $DBList = $DBList | Where-Object {$_ -ne $db.name}
        }
    }
    if ($DBList.Length > 0) {
        Write-Host(($R1.Replace("no ", "")).Replace("1", "0"))
        if ($Fix_Allowed -eq 1) {
        $Query = "USE <database>;`nGO`nREVOKE CONNECT FROM guest"
            $UserInput = Read-Host("disable 'guest' user connect permission on all databases by running the following? [Y/n]`n$Query`n")
            if ($UserInput -Notmatch "n") {
                foreach($db in $DBList) {
                    Invoke-Sqlcmd -Query $Query.Replace("<database>", $db)
                }
                Write-Host($R1.Replace("found ", ""))
                return 1
            }
            else {
                $UserInput = Read-Host("disable 'guest' user connect permission on specific databases? [Y/n]")
                if ($UserInput -Notmatch "n") {
                    foreach($db in $DBList) {
                        $UserInput = Read-Host("disable 'guest' user connect permission on $db? [Y/n]")
                        if ($UserInput -Notmatch "n") {
                            Invoke-Sqlcmd -Query $Query.Replace("<database>", $db)
                        }
                    }
                    foreach ($db in $DBList) {
                        if (-Not (Invoke-Sqlcmd -Query $Q1.Replace("<database", $db)).DBName) {
                            $DBList.Remove($db)
                            $DBList = $DBList | Where-Object {$_ -ne $db}
                        }
                    }
                    if ($DBList.Length > 0) {
                        Write-Host($R1.Replace("found ", ""))
                        return 1
                    }
                }
            }
        }
        return 0
    }
    else {
        Write-Host($R1)
        return 1
    }
}

# 3.3
function OrphanedUsers {
    $Q0 = "EXEC sp_change_users_login 'Report';"
    $QueryResults = @(Invoke-Sqlcmd -Query $Q0)
    $R1 = "No orphaned users +1"
    if ($QueryResults) {
        Write-Host("The following orphaned users found: +0`n$QueryResults")
        if ($Fix_Allowed -eq 1) {
            $Q1 = "DROP USER <login>" #removing user
            $Q2 = "EXEC sp_change_users_login 'Update_One', <database_user>, <login>" #re-mapping user
            $UserInput = Read-Host("Remove or Map orphaned users by running one of the following? [Y/n]`n$Q1`n$Q2`n")
            if ($UserInput -Notmatch "n") {
                $db_principals = @(Invoke-Sqlcmd -Query "SELECT name FROM sys.database_principals")
                foreach ($usr in $QueryResults) {
                    if ($db_principals.IndexOf($usr) -ne -1) {
                        $UserInput = @(Read-Host("Link orphaned user to the database user sharing the name $($usr)?"), 0)
                    }
                    else {
                        $UserInput = @(Read-Host("Remove orphaned user with name $($usr)?"), 1)
                    }
                    if ($UserInput -Notmatch "n") {
                        Invoke-Sqlcmd -Query $($(if ($UserInput[1]){$Q2} else{$Q1}) -Replace "(<database_user>)|(<login>)", $usr)
                    }
                }
                $QueryResults = Invoke-Sqlcmd -Query $Q0
                if (-not $QueryResults) {
                    Write-Host($R1)
                    return 1
                }
            }
        }
        return 0
    }
    else {
        Write-Host($R1)
        return 1
    }
}

# 3.4
function Contained_Authentication {
    $DBList = @(Invoke-Sqlcmd -Query "SELECT name FROM sys.databases WHERE containment <> 0;")
    $DBDict = @{}
    foreach ($db in $DBList) {
        $QueryResults = @(Invoke-Sqlcmd -Query "SELECT name FROM sys.database_principals
            WHERE name NOT IN ('dbo', 'INFORMATION_SCHEMA', 'sys', 'guest')
            AND type IN ('U', 'S', 'G') AND authentication_type = 2;
            GO").name
        if ($QueryResults) {
            $DBDict.Add($db, $QueryResults)
        }
    }
    if ($DBDict.Count) {
        Write-Host("The following contained databases and accounts use non-Windows authentication: +0")
        $DBDict.Keys | Select @{l = "Database"; e = {$_}}, @{l = "Account(s)"; e = {$DBDict.$_}}
        if ($Fix_Allowed -eq 1) {
            Write-Host("Disable SQL authentication for the above user accounts on their respective databases to remediate.")
        }
        return 0
    }
    else {
        Write-Host("All contained databases using strictly windows authentication +1")
        return 1
    }
}

# 4.2
function CheckExpiration {
    $Q1 = "SELECT l.[name], 'sysadmin membership' AS 'Access_Method'
        FROM sys.sql_logins AS l
        WHERE IS_SRVROLEMEMBER('sysadmin',name) = 1
        AND l.is_expiration_checked <> 1
        UNION ALL
        SELECT l.[name], 'CONTROL SERVER' AS 'Access Method'
        FROM sys.sql_logins AS l
        JOIN sys.server_permissions AS p
        ON l.principal_id = p.grantee_principal_id
        WHERE p.type = 'CL' AND p.state IN ('G', 'W')
        AND l.is_expiration_checked <> 1;"
    $R1 = "All users with Sysadmin role have CHECK_EXPIRATION +1"
    $QueryResults = @(Invoke-Sqlcmd -Query $Q1).name
    if ($QueryResults) {
        Write-Host(($R1.Replace("All", "Not all")).Replace("1", "0"))
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER LOGIN <login_name> WITH CHECK_EXPIRATION = ON;"
            $UserInput = Read-Host("set 'CHECK_EXPIRATION' for all sysadmin users by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                foreach ($usr in $QueryResults) {
                    Invoke-Sqlcmd -Query $Query.Replace("<login_name>", $usr)
                }
                Write-Host($R1)
                return 1
            }
            else {
                $UserInput = Read-Host("Set 'CHECK_EXPIRATION' for some sysadmin users? [Y/n]")
                if ($UserInput -Notmatch "n") {
                    foreach ($usr in $QueryResults) {
                        $UserInput = Read-Host("Set 'CHECK_EXPIRATION' for $usr? [Y/n]")
                        if ($UserInput -Notmatch "n") {
                            Invoke-Sqlcmd -Query $Query.Replace("<login_name>", $usr)
                        }
                    }
                    if (-Not (Invoke-Sqlcmd -Query $Q1)) {
                        Write-Host($R1)
                        return 1
                    }
                }
            }
        }
        return 0
    }
    else {
        Write-Host($R1)
        return 1
    }
}

# 4.3
function CheckPolicy {
    $Q0 = "SELECT name, CAST(is_disabled as int) as is_disabled
        FROM sys.sql_logins
        WHERE is_policy_checked = 0;"
    $Q1 = "ALTER LOGIN <login> WITH CHECK_POLICY = ON"
    $R0 = "'CHECK_POLICY' enabled on all SQL authenticated logins +1"
    $R1 = "Enable 'CHECK_POLICY' on all SQL authenticated logins? [Y/n]"
    $QueryResults = @(Invoke-Sqlcmd -Query $Q0)
    if ($QueryResults) {
        if ($QueryResults.is_disabled.Contains(0)) {
            Write-Host("'CHECK_POLICY' not enabled on the following SQL authenticated logins +0")
            Write-Host($QueryResults)
            if ($Fix_Allowed -eq 1) {
                $UserInput = Read-Host("by running the following? [Y/n]`n$($Query)`n")
                if ($Fix_Allowed) { $fix = 0
                $UserInput = Read-Host($R1)
                if ($UserInput -notmatch "n") { $fix = 1 }
                else { $UserInput = Read-Host($R1.Replace("all", "some"))
                    if ($UserInput -notmatch "n") { $fix = 2 }
                }
                if ($fix) {
                    foreach ($usr in $QueryResults) {
                        $UserInput = if($fix -eq 2) {Read-Host "Enable 'CHECK_POLICY' on $($usr)? [Y/n]"} else {"Y"}
                        if ($UserInput -notmatch "n") {
                            Invoke-Sqlcmd -Query $Q1.Replace("<login>", $usr)
                        }
                    }
                }
            }
            }
            return 0
        }
        $QueryResults = @(Invoke-Sqlcmd -Query $Q0.Replace("0", "0 AND is_disabled =1"))
        if ($QueryResults.is_disabled.Contains(1)) {
            Write-Host("CHECK_POLICY not enabled on the following disabled SQL authenticated login(s)")
            if ($Fix_Allowed) { $fix = 0
                $UserInput = Read-Host($R1.Replace("all", "all disabled"))
                if ($UserInput -notmatch "n") { $fix = 1 }
                else { $UserInput = Read-Host("Enable 'CHECK_POLICY' on some disabled SQL authenticated logins? [Y/n]")
                    if ($UserInput -notmatch "n") { $fix = 2 }
                }
                if ($fix) {
                    foreach ($usr in $QueryResults) {
                        $UserInput = if($fix -eq 2) {Read-Host "Enable 'CHECK_POLICY' on $($usr)? [Y/n]"} else {"Y"}
                        if ($UserInput -notmatch "n") {
                            Invoke-Sqlcmd -Query $Q1.Replace("<login>", $usr)
                        }
                    }
                }
            }
        }
        $QueryResults = @(Invoke-Sqlcmd -Query $Q0)
        if ($QueryResults.is_disabled.Contains(0)) {
            Write-Host($R0)
            return 1
        }
    }
    else {
        Write-Host($R0)
        return 1
    }
}

# 5.1
function MaxLogFiles {
   $QueryResults = @(Invoke-Sqlcmd -Query "DECLARE @NumErrorLogs int;
        EXECUTE master.sys.xp_instance
        N'HKEY LOCAL MACHINE',
        N'Software\Microsoft\MSSQLServer\MSSQLServer',
        N'NumErrorLogs',
        @NumErrorLogs OUTPUT;
        SELECT ISNULL(@NumErrorLogs, -1) AS [NumberOfLogFiles];")
    if ($QueryResults.config_value -ne 0 -or $QueryResults.run_value -ne 0) {
        Write-Host("xp_cmdshell enabled +0")
        if ($Fix_Allowed -eq 1) {
            $Query = "EXECUTE sp_configure 'xp_cmdshell', 0;`nRECONFIGURE;"
            $UserInput = Read-Host("disable xp_cmdshell by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                Invoke-Sqlcmd -Query $Query
                Write-Host("xp_cmdshell disabled +1")
                return 1
            }
        }
        return 0
    }
    else {
        Write-Host("xp_cmdshell disabled +1")
        return 1
    }
}

# 6.2
function CLRAssemblyPermission {
    $Q1 = "SELECT name FROM sys.assemblies WHERE is_user_defined = 1
        AND permission_set_desc = 'UNSAFE_ACCESS';"
    $R1 = "all CLR assemblies set to 'SAFE ACCESS' +1"
    $QueryResults = @(Invoke-Sqlcmd -Query $Q1)
    if ($QueryResults.config_value -ne 0 -or $QueryResults.run_value -ne 0) {
        Write-Host(($R1.Replace("all", "not all")).Replace("1", "0"))
        if ($Fix_Allowed -eq 1) {
            $Query = "ALTER ASSEMBLY <assembly> WITH PERMISSION_SET = SAFE"
            $UserInput = Read-Host("Set all assemblies to 'SAFE ACCESS' by running the following? [Y/n]`n$($Query)`n")
            if ($UserInput -Notmatch "n") {
                foreach ($asm in $QueryResults) {
                    Invoke-Sqlcmd -Query $Query.Replace("<assembly>", $asm)
                }
                Write-Host($R1)
                return 1
            }
            else {
                $UserInput = Read-Host("Set some assemblies to 'SAFE ACCESS'? [Y/n]")
                if ($UserInput -Notmatch "n") {
                    foreach ($asm in $QueryResults) {
                        $UserInput = Read-Host("Set $asm to 'SAFE ACCESS'? [Y/n]")
                        if ($UserInput -Notmatch "n") {
                            Invoke-Sqlcmd -Query $Query.Replace("<assembly>", $asm)
                        }
                    }
                    if (-Not (Invoke-Sqlcmd -Query $Q1)) {
                        Write-Host($R1)
                        return 1
                    }
                }
            }
        }
        return 0
    }
    else {
        Write-Host($R1)
        return 1
    }
}

# 7.1
function SymmetricEncryptionAlgorithm {
    $DBList = @(Invoke-Sqlcmd -Query "SELECT name FROM sys.databases
        WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')").name
    foreach ($db in $DBList) {
        $QueryResults = @(Invoke-Sqlcmd -Query "USE $db
            GO
            SELECT db_name() AS name, name AS Key_name
            FROM sys.symmetric_keys WHERE algorithm_desc NOT IN ('AES_128', 'AES_192', 'AES_256');
            GO")
        if (-Not $QueryResults.Key_name) {
            $DBList = $DBList | Where-Object {$_ -ne $db}
        }
    }
    if ($DBList) {
        Write-Host("The following databases use a symmetric key less secure than AES 128: +0`n$DBList")
        if ($Fix_Allowed -eq 1) { #TODO implement script for adding new key https://msdn.microsoft.com/en-us/library/ms189440.aspx
            Write-Host("Use AES 128 or better symmetric algorithm.")
        }
        return 0
    }
    else {
        Write-Host("Good symmetric key algorithm +1")
        return 1
    }
}

# 7.2
function AsymmetricKeySize {
    $DBList = @(Invoke-Sqlcmd -Query "SELECT name FROM sys.databases
        WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')").name
    foreach ($db in $DBList) {
        $QueryResults = @(Invoke-Sqlcmd -Query "USE $db
            GO
            SELECT db_name() AS name, name AS Key_name
            FROM sys.asymmetric_keys WHERE key_length < 2048;
            GO")
        if (-Not $QueryResults.Key_name) {
            $DBList = $DBList | Where-Object {$_ -ne $db}
        }
    }
    if ($DBList) {
        Write-Host("The following databases use an asymmetric key with a size < 2048: +0`n$DBList")
        if ($Fix_Allowed -eq 1) { #TODO implement script for adding new key https://msdn.microsoft.com/en-us/library/ms187311.aspx
            Write-Host("Use a key size greater than 2048.")
        }
        return 0
    }
    else {
        Write-Host("Good asymmetric key size +1")
        return 1
    }
}


function main {
    $SQLVersion = [int](Invoke-Sqlcmd -Query "SELECT @@VERSION").Column1.Substring(23, 2)
    $Score = 0

    if (Read-Host("Would you like to see potential fixes for problems found? [N/y]") -Notmatch "y") {
        $Fix_Allowed = 1
    }

    #starting scoring
    Invoke-Sqlcmd -Query "EXECUTE sp_configure 'show advanced options', 1; RECONFIGURE;"

    $Score += (S-Name_Conf_InUse.F-SysConf "'ad hoc distributed queries'" ) + # 2.1
              (S-Name_Conf_InUse.F-SysConf "'clr enabled'") + # 2.2
              (S-Name_Conf_InUse.F-SysConf "'Cross db ownership chaining'") + # 2.3
              (S-Name_Conf_InUse.F-SysConf "'Database Mail XPs'" )+ # 2.4
              (S-Name_Conf_InUse.F-SysConf "'Ole Automation Procedures'" )+ # 2.5
              (S-Name_Conf_InUse.F-SysConf "'Remote access'") + # 2.6
              (S-Name_Conf_InUse.F-SysConf "'Scan for startup procs'")  # 2.8
         $Score +=     RemoteAdminConnection # 2.9
              if ((Invoke-Sqlcmd "SELECT SERVERPROPERTY('IsClustered') AS is_clustered;").is_clustered -eq 0) { # if server is not clustered
                $Score += S-Name_Conf_InUse.F-SysConf -Name "'Remote admin connections'" -PreQ "USE master; " # 2.7
                if ($SQLVersion -eq 14) {$Score += HideInstance} # 2.12
              }
    $SaScore= saDisabled_Renamed # 2.13 - 2.14
    $Score += $SaScore[0] + $SaScore[1]
    $Score += NosaAccount + # 2.17
              xp_cmdshell + # 2.15
              Contained_AutoClose + # 2.16
              ServerAuthentication + # 3.1
              GuestConnect + # 3.2
              OrphanedUsers + # 3.3
              Contained_Authentication # 3.4
    if ($SQLVersion -eq 14) {$Score += MaxLogFiles} # 5.1
    $Score += S-Name_Conf_InUse.F-SysConf -Name "'Default trace enabled'" -Value 1 # 5.2
    $Score += CLRAssemblyPermission + # 6.2
              SymmetricEncryptionAlgorithm + # 7.1
              AsymmetricKeySize # 7.2




    Invoke-Sqlcmd -Query "EXECUTE sp_configure 'show advanced options', 0; RECONFIGURE;"
    
    Write-Host("Benchmark Score of $($Score) / 29")
}

main
