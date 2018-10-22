param([string] $serverName = "DOKI\SQLExpress2014", 
      [string] $BackupFolder = "D:\Backups\",
      [string] $SQLSourceEmail = "DOKI-SQLExpress2012@ntfy.cesar.org.br",
      [string] $DBAEmail = "iatj@cesar.org.br",
      [string] $SmtpTargetServer = "notify.cesar.org.br",
      [string] $LogPath = "C:\Temp\")

$timeStamp = Get-Date -format yyyy_MM_dd_HHmmss 
 
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null


# Verifica se LogPath existe e cria caso inexistente
if( -Not (Test-Path -Path $LogPath ) )
{
    New-Item -ItemType Directory -Force -Path $LogPath
}

# Iniciar Log
(Get-Date).ToString() + " - Log Path: " + ($LogPath).ToString() + "Backup_SQLDatabases_v2_LOG_"+ ($timeStamp).ToString() + ".txt" | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
echo `n | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
(Get-Date).ToString() + " - Inicio Processamento" | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append

$srv = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $serverName

## Verifica se a Instancia SQL está ativa
if($srv.InstanceName -eq $null -and $srv.Information.ResourceVersion -eq $null)
{    
    echo `n | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
    (Get-Date).ToString() + " - Erro ao acessar " + $serverName  | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
    echo `n | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
}
else 
{
    (Get-Date).ToString() + " - SQL Instance: " + $env:computername + "\" + $srv.InstanceName + " - Engine: " + ($srv.EngineEdition).ToString() +  " - Version: " + ($srv.Version).ToString() | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
    echo `n | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append


    $dbs = New-Object Microsoft.SqlServer.Management.Smo.Database 
    $dbs = $srv.Databases 

    foreach ($Database in $dbs) 
    { 

        if($Database.Name -ne "tempdb" -and $Database.status -eq "Normal"  ) 
        {   
        
            $TargetDir = $BackupFolder + "Automatico\" + ($Database.Name).ToString()

            # Verifica se Path\<database name> existe e cria caso n�o exista
            if( -Not (Test-Path -Path $TargetDir ) )
            {
                (Get-Date).tostring() + "- Criar diretorio: " + $TargetDir | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
                New-Item -ItemType Directory -Force -Path $TargetDir
            }
            
            (Get-Date).ToString() + " - Iniciar backup de " + ($Database.name).tostring() | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
            
            $bk = New-Object ("Microsoft.SqlServer.Management.Smo.Backup") 
            $bk.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database 
            $bk.BackupSetName = $Database.Name + "_FULL_" + $timeStamp
            $bk.Database = $Database.Name 
            
            # Habilita compressao se Engine suportar. Express n�o suporta CompressionOption
            if($srv.EngineEdition -eq "Express")
                { $bk.CompressionOption = 0 }
            else 
                { $bk.CompressionOption = 1 }

            $BackupFileName = $TargetDir + "\" + $Database.Name + "_FULL_" + $timeStamp + ".bak"   
            $bk.MediaDescription = "Disk"
            $bk.Devices.AddDevice($BackupFileName , "File") 
            
            TRY {
                $bk.SqlBackup($srv)
                (Get-Date).ToString() + "   . Backup Path: " + $BackupFileName | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
            } 
            CATCH 
            {
                $Database.Name + " backup failed." | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
                $_.Exception.Message | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
            } 
        }
    } 

    echo `n | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
    (Get-Date).ToString() + " - Fim do Processamento" | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
}

# Enviar Email 
$SubjectEmail = "Backup SQL Server; " + ($env:computername).ToString() + "\" + ($srv.InstanceName).ToString()
$BodyEmail = "Backup SQL Server. Verifique pasta destino: " + ($BackupFolder).ToString()

(Get-Date).ToString() + " - Enviar Email" | Out-File $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" -Width 256 -Encoding ascii -Force -Append
Send-MailMessage -To $DBAEmail -From $SQLSourceEmail -SMTPServer $SmtpTargetServer -Subject $SubjectEmail -Body $BodyEmail -Attachments $LogPath"Backup_SQLDatabases_v2_LOG_"$timeStamp".txt" 
