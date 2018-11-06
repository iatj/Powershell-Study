#Requires -Version 4
#Requires -Modules SQLPS
#Requires -RunAsAdministrator 

<# 
Script to modify and list Recovery Model of all SQL user databases on current SQL server
Returns object with 3 properties: ServerName, DatabaseName, RecoveryModel
For more information see https://superwidgets.wordpress.com/2016/03/21/sql-backup-options-and-feature-details/
Sam Boutros - 5 June 2016 - v1.0
#>

#region Input
    $DesiredRecoveryModel = 'SIMPLE' # Valid options are SIMPLE, FULL and BULK_LOGGED (upper case)
#endregion

$Output = @()
 (Invoke-SQLCMD -Query "SELECT * FROM sysdatabases WHERE dbid > 4") | % { # skipping first 4 databases: master, tempdb, model, msdb
    Invoke-Sqlcmd -Query "USE master; ALTER DATABASE ""$($_.name)"" SET RECOVERY $DesiredRecoveryModel"
    $DBProps = Invoke-Sqlcmd -Query "SELECT * FROM sys.databases WHERE name = '$($_.name)'" 
    $Output += New-Object -TypeName PSObject -Property ([Ordered]@{
        ServerName    = $env:COMPUTERNAME
        DatabaseName  = $_.name
        RecoveryModel = $DBProps.recovery_model_desc
    })
}
$Output | sort RecoveryModel | FT -a