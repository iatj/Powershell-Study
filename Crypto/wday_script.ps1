    # Mandatory Framework .NET Assembly
    Add-Type -assembly System.Security
    [void][Reflection.Assembly]::LoadWithPartialName("System.Data")
    [void][Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    [void][Reflection.Assembly]::LoadWithPartialName("System.Data.SqlClient") 


    ###Variable Set
    $Root = "D:\xDir\Data\ScoutReviewTool";#"D:\DRPP\xDirFiles";

    $pwdTxt = "$Root\Util\key.txt"
    $xDirFolder = "D:\xDir\Data\ScoutReviewTool\Fake_NAS\"  
    #$xDirFolder = "\\RR2CVNX02MP02.amer.dell.com\SCOUT_36105nonprodMP\xDir\DEV\"
    
    $xDirFileName = 'Test_INT636_Global_SCOUT*.txt.pgp' #<<Remove Test Prefix    
    
    $ProcessFolder ="$Root"
    $ProcessFolderDecrypted ="$Root\Processed" #Decripted
    $ProcessFolderEncrypted ="$Root\Stage"    #Encrypt
    $ArchiveFolder = "$Root\Archive"

    $Encrypted = "Global_Scout.txt.pgp"
    $Decrypted = "Global_Scout.txt"
    $GPGLocation = '"D:\Program Files\GnuPG\pub\gpg.exe"'
    

    $logfile = "D:\xDir\Log\$(get-date -format `"yyyyMMdd_hhmmsstt`")_LogGlobal_Scout.txt"
    $limit = (Get-Date).AddDays(-30)

    # Database variables 
    
    $Sqlserver = "AUSIWSCOUTDB01.aus.amer.dell.com";
    $Database = "Scout_ETL";
    
    $dbFile = Get-Content -Path D:\xDir\Data\database_credential.json | ConvertFrom-Json
    $dbSecure = ConvertTo-SecureString $dbFile.Password -ErrorAction Stop
    $dbNewcred = New-Object -TypeName PSCredential $dbFile.username,$dbSecure
    $dbPwd = $dbNewcred.GetNetworkCredential().Password

    $Connection = "Data Source=$Sqlserver;USER ID=scoutcloud_devdbadmin;PASSWORD=$dbPwd;Initial Catalog=$Database;";
    #$Connection = "Data Source=$Sqlserver;Integrated Security=true;Initial Catalog=$Database;";

    # TXT variables 
    $CSVdelimiter = "," 
    $firstRowColumnNames = $true
    $timeOut = 300;
    $fieldsEnclosedInQuotes = $true


    ###End-Variable Set


    function Get-TimeStamp {
        $timeStamp = "[" + (Get-Date).ToShortDateString() + " " + ((Get-Date).ToLongTimeString()) + "]" 
        Return $timeStamp   
    }


    function Main()
    {

        Write-Output "$(Get-TimeStamp) Starting file process." | Out-file $logfile -append
        $fileStatus = New-Object System.Collections.Generic.List[System.Object]

        Try
        {

            ###Cleanup processing folder
            Remove-Item "$ProcessFolderDecrypted\*" -recurse
            ####End Cleanup

            ###Get Latest File and copy to the Archive and Processing Folder
            $LatestFile =  @(Get-ChildItem -Path $xDirFolder -filter $xDirFileName  | Sort-Object LastAccessTime -Descending | Select-Object -First 1)

            if ($LatestFile.length -eq 0) {
            Write-Output "$(Get-TimeStamp) No File to process." | Out-file $logfile -append
            
            }#if
            else
            {
                Write-Output "$(Get-TimeStamp) Copying file to Archive and Processing folder: $LatestFile" | Out-file $logfile -append
                Copy-Item  -path "$xDirFolder\$LatestFile"  -Destination "$ArchiveFolder" 
                Copy-Item  -path "$xDirFolder\$LatestFile"  -Destination "$ProcessFolderEncrypted\$Encrypted"  
                ##End Copy File

                ##Decrypt File in the processing folder
                Write-Output "$(Get-TimeStamp) Starting decryption process." | Out-file $logfile -append

                ##Decrypt xDir Password
                Write-Output "$(Get-TimeStamp) Starting decryption password." | Out-file $logfile -append
                $file = Get-Content -Path D:\xDir\Data\xDir_credential.json | ConvertFrom-Json
                $secure = ConvertTo-SecureString $file.Password -ErrorAction Stop
                $newcred = New-Object -TypeName PSCredential $file.username,$secure

                $pwdClean = $newcred.GetNetworkCredential().Password

                Write-Output "$(Get-TimeStamp) Password decryption ended." | Out-file $logfile -append
                ##End Password Decrypt process

                #PROD ONLY
                #cmd /c "$GPGLocation --batch --yes --homedir $GPHome --passphrase ""$pwdClean"" -o $ProcessFolderDecrypted\$Decrypted -d $ProcessFolderEncrypted\$Encrypted 2>&1" | Out-file $logfile -append

                #DEV ONLY
                cmd /c "$GPGLocation --batch --yes --passphrase ""$pwdClean"" -o $ProcessFolderDecrypted\$Decrypted -d $ProcessFolderEncrypted\$Encrypted 2>&1" | Out-file $logfile -append

                Write-Output "$(Get-TimeStamp) Decryption ended." | Out-file $logfile -append
                    Remove-Item "$ProcessFolderEncrypted\$Encrypted" 
                ##End Decrypt process
            
                <#  Call Procedure to clean up staging tables#>
                $ProcedureCleanName = "wd_clean_TB_LOAD_DATA_table"

                RunProcedure $Connection $ProcedureCleanName $Database

                <#  Load file decrypted into stagging table#>
                $Table = "TB_LOAD_DATA"

                RunLoadFlatFile $Connection $Table "$ProcessFolderDecrypted\$Decrypted"

                <#  Call Procedure to propagete xDir data into Scout #>
                $ProcedurePropagateName = "sp_Load_TB_LOAD_DATA_hierarchy"

                RunProcedure $Connection $ProcedurePropagateName $Database

            }#else


            Write-Output "$(Get-TimeStamp) Deleting old files." | Out-file $logfile -append
            ###This is for creation date:  Get-ChildItem -Path $ArchiveFolder -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
            ### Get-ChildItem -Path $ArchiveFolder -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $limit } | Remove-Item -Force | Out-file $logfile -append
            
            $fileStatus.Add(0) #Success
            
    
        }#try
        Catch{
            Write-Output "[$(Get-TimeStamp)] -[ERROR] - Failure: $_.Exception.Message"  | Out-file $logfile -append
            $fileStatus.Add(1) #Failure
            
        }#catch
        
        Write-Output "$(Get-TimeStamp) End all." | Out-file $logfile -append
        Get-Status($fileStatus)
    }#main

    function Get-Status($statusArray){
        if($statusArray -contains 1){
            exit 1
        }
        else{
            exit 0
        }   
    }

    function RunProcedure($connection, $procedureName, $database){
        Write-Output "[$(Get-TimeStamp)] - [START] RunProcedure - $procedureName" | Out-file $logfile -append
        Try{
            $SqlConnection = New-Object System.Data.SqlClient.SqlConnection;
            $SqlConnection.ConnectionString = $connection;
            $SqlCommand = $SqlConnection.CreateCommand();
            $SqlCommand.CommandText = "exec $database.[dbo].[$procedureName]";
            $SqlCommand.CommandTimeout = $timeOut
            $SqlConnection.Open();
            $returnedValue = $SqlCommand.ExecuteNonQuery();        
        }
        Catch{
            throw $_.Exception
        }
        Finally{
            $SqlConnection.Dispose();
            $SqlConnection.Close();
        }    
        Write-Output "[$(Get-TimeStamp)] - [END] - RunProcedure" | Out-file $logfile -append
    }

    function RunLoadFlatFile($connection, $table, $loadFile){
        Write-Output "[$(Get-TimeStamp)] - [START] - RunLoadFlatFile - $table - $loadFile" | Out-file $logfile -append
        Try{
            $elapsed = [System.Diagnostics.Stopwatch]::StartNew()  
            
            # 50k worked fastest and kept memory usage to a minimum 
            $batchsize = 50000 
        
            #Bforfiles uild the sqlbulkcopy connection, and set the timeout to infinite     

            $bulkCopyOptions = 0
            $options = "TableLock", "FireTriggers"

            foreach ($option in $options) {
                $bulkCopyOptions += $([Data.SqlClient.SqlBulkCopyOptions]::$option).value__
            }

            $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($connection, $bulkCopyOptions) 
            #$bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($connection, [System.Data.SqlClient.SqlBulkCopyOptions]::FireTriggers) 
            
            $bulkcopy.DestinationTableName = $table 
            $bulkcopy.bulkcopyTimeout = 0 
            $bulkcopy.batchsize = $batchsize
    
            
            # Create the datatable, and autogenerate the columns. 
            # Open text parser for the column names
            $columns = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($loadFile)
            $columns.TextFieldType = "Delimited"
            $columns.HasFieldsEnclosedInQuotes = $fieldsEnclosedInQuotes
            $columns.SetDelimiters($CSVdelimiter)

            $datatable = New-Object System.Data.DataTable
            foreach ($column in $columns.ReadFields()) {[void]$datatable.Columns.Add($column)} 
            $columns.Close(); $columns.Dispose()
    
            # Open the text file from disk 
            #$reader = New-Object System.IO.StreamReader($loadFile) 
            $reader = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($loadFile)
            $reader.TextFieldType = "Delimited"
            $reader.HasFieldsEnclosedInQuotes = $fieldsEnclosedInQuotes
            $reader.SetDelimiters($CSVdelimiter)

            #skip column headers row
            if ($firstRowColumnNames -eq $true) {$null = $reader.ReadFields()}

            # Read in the data, line by line, not column by column 
            while (!$reader.EndOfData) {
                try { $null = $datatable.Rows.Add($reader.ReadFields()) }
                catch { Write-Warning "Row $i could not be parsed. Skipped." }

            }

            
            $rowCount = $datatable.Rows.Count
            # Import and empty the datatable before it starts taking up too much RAM, but  
            # after it has enough rows to make the import efficient. 
                $i++; if (($i % $batchsize) -eq 0) {  	
                    $bulkcopy.WriteToServer($datatable)                      
                    Write-Output $rowCount" rows have been inserted in $($elapsed.Elapsed.ToString())." | Out-file $logfile -append
                    $datatable.Clear()  
                }  
              
    
            # Add in all the remaining rows since the last clear 
            if($datatable.Rows.Count -gt 0) { 
                $bulkcopy.WriteToServer($datatable) 
                $datatable.Clear() 
            }
            
            Write-Output "Script complete. $rowCount rows have been inserted into the database." | Out-file $logfile -append
            Write-Output "Total Elapsed Time: $($elapsed.Elapsed.ToString())" | Out-file $logfile -append
        }
        Catch{
            throw $_.Exception
        }
        Finally{
            # Clean Up 
            $reader.Close(); $reader.Dispose() 
            $bulkcopy.Close(); $bulkcopy.Dispose() 
            $datatable.Dispose()
        
            # Sometimes the Garbage Collector takes too long to clear the huge datatable. 
            [System.GC]::Collect()
        }
        Write-Output "[$(Get-TimeStamp)] - [END] - RunLoadFlatFile" | Out-file $logfile -append
    }




    Main