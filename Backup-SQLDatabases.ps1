<# 
    Script to create SQL Server Backups
    
    i3 Data Dominus
    
    Author: Ivan Tavares Junior     -   05 November 2018

    Goal: Create SQL Server database Backups
    
    # -------------------------------------------------------------------------------------------------------------- +        

    Example:

    powershell.exe -ExecutionPolicy Bypass D:\Backups\Batchs\Powershell\Backup-SQLDatabases_v4.ps1 -BackupType FULL -servername MIDWAY\SQLExpress2008r2 -BackupFolder \\fobos\Backup\Midway\SQLExpress2008r2\ -SQLSourceEmail MIDWAY-SQLExpress2008r2@gmail.com -DBAEmail dba-l_ServerSQL@gmail.com -SmtpTargetServer smtp.gmail.com -LogPath D:\Backups\Logs\SQLExpress2008r2\

#>

param(  [Parameter(Mandatory=$True,Position=1)] [ValidateSet("FULL", "DIFF", "TLOG")] [string] $BackupType = "FULL",
        [Parameter(Mandatory=$True,Position=2)] [string] $serverName = "SQLServer\SQLExpress2014", 
        [Parameter(Mandatory=$True,Position=3)] [string] $BackupFolder = "D:\Backups\",
        [Parameter(Mandatory=$True,Position=4)] [string] $SQLSourceEmail = "SQLServer@gmail.com",
        [Parameter(Mandatory=$True,Position=5)] [string] $DBAEmail = "dba-l_SQLServer@gmail.com",
        [Parameter(Mandatory=$True,Position=6)] [string] $SmtpTargetServer = "smtp.gmail.com",
        [Parameter(Mandatory=$True,Position=7)] [string] $LogPath = "C:\Temp\",
        [Parameter(Mandatory=$false,Position=8)] [ValidateRange(-15,0)] [Int] $DaysToKeep = -3
        )

## Definir Local (PATH) e Nome do Arquivo de Saida (LogFileNameComplete)
$timeStamp = Get-Date -format yyyy_MM_dd_HHmmss 
$LogFileName = "Backup_SQLDatabases_BkpType_" + ($BackupType).ToString() + "_OUTPUT_"
$LogFileNameComplete = ($LogPath).ToString()+($LogFileName).ToString()+$timeStamp.ToString()+".txt"

## Definir parametros para remover arquivos antigos
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($DaysToKeep)

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null


## Verifica se LogPath existe e cria caso inexistente
if( -Not (Test-Path -Path $LogPath ) )
{
    New-Item -ItemType Directory -Force -Path $LogPath
}

## Iniciar Log
(Get-Date).ToString() + " - Log Path: " + ($LogFileNameComplete).ToString() | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
(Get-Date).ToString() + " - Inicio Processamento" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
(Get-Date).ToString() + " - Data limite para manter arquivos antigos" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

$srv = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $serverName

## Verifica se a Instancia SQL esta ativa
if([string]::IsNullOrEmpty($srv.InstanceName) -and [string]::IsNullOrEmpty($srv.Information.ResourceVersion))
{    
    Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
    (Get-Date).ToString() + " - Erro ao acessar " + $serverName  | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
    Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

    $BodyEmail = "Backup SQL Server [Erro]. Verifique Log " + ($LogFileNameComplete).ToString()
}
else 
{
    (Get-Date).ToString() + " - SQL Instance: " + $env:computername + "\" + $srv.InstanceName + " - Engine: " + ($srv.EngineEdition).ToString() +  " - Version: " + ($srv.Version).ToString() | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
    Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

    $dbs = New-Object Microsoft.SqlServer.Management.Smo.Database 
    $dbs = $srv.Databases 

    foreach ($Database in $dbs) 
    {   
        # Listar Bancos e suas propriedades.
        # (Get-Date).ToString() + " - Banco de dados:  " + ($Database.name).tostring() + " - Recovery Model: " + ($Database.RecoveryModel).ToString() +  " - Status: " + ($Database.status).ToString() | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

        if($Database.Name -ne "tempdb" -and ($Database.status).ToString().Contains("Normal") ) 
        {   
            # Instanciar Objeto de Backup        
            $bk = New-Object ("Microsoft.SqlServer.Management.Smo.Backup") 

            $TargetDir = $BackupFolder + "Automatico\" + ($Database.Name).ToString()

            if (($BackupType).ToString() -eq "DIFF")
            {   
                if(($Database.RecoveryModel).ToString() -eq "Simple")
                {
                    (Get-Date).ToString() + " - Desconsiderar: " + ($Database.name).tostring() + " - Recovery Model: " + ($Database.RecoveryModel).ToString() + " Inadequado para Backup Incremental" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
                    # Buscar Proximo Item
                    Continue
                }
                else 
                {
                    $TargetDir = ($TargetDir).ToString()+"\DIFF\"
                    $bk.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database
                    $bk.Incremental = $TRUE
                }
            }
            elseif (($BackupType).ToString() -eq "TLOG")
            {   
                if(($Database.RecoveryModel).ToString() -eq "Simple")
                {
                    (Get-Date).ToString() + " - Desconsiderar: " + ($Database.name).tostring() + " - Recovery Model: " + ($Database.RecoveryModel).ToString() + " Inadequado para Backup de T-Log" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
                    # Buscar Proximo Item
                    Continue
                }
                else 
                {
                    $TargetDir = ($TargetDir).ToString()+"\LOG\"
                    $bk.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Log
                
                }
            }
            elseif (($BackupType).ToString() -eq "FULL")
            {   $bk.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database }

            # Configurar propriedades do Backup
            $bk.Database = $Database.Name 
            $bk.BackupSetName = ($Database.Name).ToString() + "_" + ($BackupType).ToString() + "_" + ($timeStamp).ToString()
            $BackupFileName = ($TargetDir).ToString() + "\" + ($bk.BackupSetName).ToString() + ".bak" 
            $bk.MediaDescription = "Disk"
            $bk.Devices.AddDevice($BackupFileName , "File") 

            # Habilita compressao se Engine suportar. Express n�o suporta CompressionOption
            if($srv.EngineEdition -eq "Express")
                { $bk.CompressionOption = 0 }
            else 
                { $bk.CompressionOption = 1 }
        
            # Verifica se Path\<database name> existe e cria se for necessario
            if( -Not (Test-Path -Path $TargetDir ) )
            {
                (Get-Date).tostring() + " - Criar diretorio: " + $TargetDir | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
                New-Item -ItemType Directory -Force -Path $TargetDir
            }
            
            (Get-Date).ToString() + " - Iniciar backup de " + ($Database.name).tostring() | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
            
            TRY 
            {
                ## Criar o arquivo de Backup
                $bk.SqlBackup($srv) 
                (Get-Date).ToString() + "   . Backup Path: " + $BackupFileName | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
                Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

                ## Exibir lista de arquivos antigos que devem ser removidos
                (Get-Date).ToString() + " - Remover arquivos antigos: " | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
                Get-ChildItem $TargetDir -Recurse -include *.trn,*.bak -file | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Add-Content -Path ($LogFileNameComplete).ToString() -Encoding ascii -Force 
                
                ## Remover os arquivos de backup listados acima
                Get-ChildItem $TargetDir -Recurse -include *.trn,*.bak -file | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item 
                Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
            } 
            CATCH 
            {
                $Database.Name + " Backup falhou !" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
                $_.Exception.Message | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
            } 
        }
    } 

    Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

    ## Finalizar o Log de processamento e enviar por email
    (Get-Date).ToString() + " - Fim do Processamento" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
    $BodyEmail = "Backup SQL Server. Verifique pasta destino: " + ($BackupFolder).ToString() + ", e log do processamento: " + ($LogFileNameComplete).ToString()
}

## Exibir lista de arquivos de log de processamento antigos que devem ser removidos
(Get-Date).ToString() + " - Remover arquivos de log antigos: " | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
Get-ChildItem $LogPath -Recurse -include *.txt -file | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-10) } | Add-Content -Path ($LogFileNameComplete).ToString() -Encoding ascii -Force 

## Remover os arquivos de log de processamento listados acima
Get-ChildItem $LogPath -Recurse -include *.txt -file | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-10) } | Remove-Item 
Write-Output `n | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append

# Enviar Email 
$SubjectEmail = "Backup SQL Server: " + ($serverName).ToString()

(Get-Date).ToString() + " - Enviar Email" | Out-File ($LogFileNameComplete).ToString() -Width 256 -Encoding ascii -Force -Append
Send-MailMessage -To $DBAEmail -From $SQLSourceEmail -SMTPServer $SmtpTargetServer -Subject $SubjectEmail -Body $BodyEmail -Attachments ($LogFileNameComplete).ToString() 
