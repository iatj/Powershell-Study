#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# This software consists of voluntary contributions made by many individuals
# and is licensed under the MIT license. For more information, see
# <http://www.doctrine-project.org>.
#
#
# @license http://www.opensource.org/licenses/mit-license.html  MIT License
# @author Ivan A. Tavares Jr <ivan.tavares.jr@gmail.com>
# 
# Recife, 15 Octobre 2018 
#

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [string]$pSQLServerInst,
   [Parameter(Mandatory=$True,Position=2)]
   [string]$pFolder_To_Log 
)

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlEnum") | out-null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | out-null

#==========================================================================
# Parameter Validation
#==========================================================================
function Create_Folder_To_LogFile {
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$Folder_To_LogFile
    )
    try{
        if (!(Test-Path $Folder_To_LogFile)){
            New-Item -path $Folder_To_LogFile -type directory -Force 
        }
    }
    catch { 
        $err = $Error[0].Exception ; 
        Write-Output "Error caught: "  $err.Message ; 
        continue ; 
    }; 
    return $Folder_To_LogFile
}

# Init LogFile
Create_Folder_To_LogFile $pFolder_To_Log
$null = Start-Transcript -path $pFolder_To_Log\SQLServer_List_Agent_jobs_Lastrun_OUTPUT_$(((get-date).ToUniversalTime()).ToString("yyyyMMdd_HHmmss")).log -Force -Append
$InformationPreference = "Continue"

#==========================================================================
# Parameter Validation
#==========================================================================
try{
    Write-Output "# Inicio SQLServer-List-Agent-Jobs-Lastrun #"

    # Init SQL Server connection
    $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $pSQLServerInst 

    if($srv.Status){
        # Create an instance of the Jobs object collection from the JobServer property, 
        # and pipes that to the filter Where-Object cmdlet to retrieve only  jobs that are enabled
        $srv.JobServer.Jobs | Where-Object {$_.IsEnabled -eq $TRUE} | format-table -property Name, LastRunOutcome, LastRunDate -AutoSize
    }else{
        Write-Output "Cannot connect to $pSQLServerInst.";
    }
}
catch { 
    $err = $Error[0].Exception ; 
    Write-Output "Error caught: "  $err.Message ; 
    continue ; 
}; 

Stop-transcript;
