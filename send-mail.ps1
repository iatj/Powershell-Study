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
   [string]$emailSmtpServer = "notify.cesar.org.br",

   [Parameter(Mandatory=$True,Position=2)]
   [string]$emailFrom = "MIDWAY - SQL Server 2008r2 <MIDWAY-SQLExpr2008r2@ntfy.cesar.org.br>",

   [Parameter(Mandatory=$True,Position=3)]
   [string]$emailTo="dba-l@cesar.org.br",

   [Parameter(Mandatory=$True,Position=4)]
   [string]$emailSubject="Backup SQL Server FULL",
   	
   [Parameter(Mandatory=$False)]
   [string]$attachment
)


$emailBody = @"
Atenção !

O recebimento deste e-mail não implica que todo o procedimento do backup tenha sido concluido corretamente. 

Valide o arquivo em anexo e caso o anexo não esteja presente verifique o servidor e pasta de backup.
"@

#   $attachment = "C:\temp\Banggood-Cancel-Orders.jpg" 
# Or do multiple attachments like this:
#   $attachment = "C:\myfile1.txt","C:\myfile2.txt"


IF ([string]::IsNullOrEmpty($attachment)) {            
    Send-MailMessage -To $emailTo -From $emailFrom -Subject $emailSubject -Body $emailBody -SmtpServer $emailSmtpServer
} ELSE {            
    Send-MailMessage -To $emailTo -From $emailFrom -Subject $emailSubject -Body $emailBody -BodyAsHTML -Attachments $attachment -SmtpServer $emailSmtpServer
}

write-host "Mail Sent"
 