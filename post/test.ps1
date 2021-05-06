Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

Function Export-UserProfileLinks($filePath) {
    Try {
        Write-Host  "Enter Export-UserProfileLinks"  
        $list = Get-UserProfileLinks
        #convert to xml
        $xmlBackup = $list | ConvertTo-FullXML -ObjectName "Link" -RootNodeName "Links"
        #write file
        $xmlBackup | Out-File -FilePath $filePath
    }		
    Catch {
        throw $_.Exception.Message
    }
    Write-Host  "Leave Export-UserProfileLinks" 
}
Function Import-UserProfileLinks($configFilePath) {   
    Try {
        Write-Host  "Enter Import-UserProfileLinks" 
        [xml] $configXml = Get-Content $configFilePath -Encoding UTF8
        foreach ($link in $configXml.UserProfileLinks.UserProfileLink) {
            Edit-UserProfileLink $link 
        }
    }		
    Catch {
        throw $_.Exception.Message
    }
    Write-Host  "Leave Import-UserProfileLinks"
}
Function Get-UserProfileLinks() {
    $profileManager = Get-UserProfileManager
    $profiles = $profileManager.GetEnumerator() 
    $all = $profileManager.Count
    $collection = @() 
    $num = 0
    foreach ($profile in $profiles) { 
        $userProfile = $profileManager.GetUserProfile($profile.AccountName);
        foreach ($link in   $userProfile.QuickLinks.GetItems() ) {
            $myLink = [PSCustomObject]@{
                AccountName  = $profile.AccountName
                Title        = $link.Title
                Url          = $link.Url
                Group        = $link.Group
                PrivacyLevel = $link.PrivacyLevel
                ID           = $link.ID
            }
            $collection += $myLink 
        }
        $num ++
        if (0 -eq ($num % 1000)) {
            Write-Host "User profiles collected $num / $all" -ForegroundColor Gray
        }
    }
    Write-Host "User profiles $num collected"
    return $collection
}
function Edit-UserProfileLink($link) {
    Try {
        $profileManager = Get-UserProfileManager
        $userProfile = $profileManager.GetUserProfile($link.AccountName);
        $userProfile.QuickLinks.Create($link.Title, $link.Url, "UserSpecified", $link.Group, $link.PrivacyLevel) | Out-Null
    }		
    Catch {
        Write-Host  "$($link.AccountName) cannot import $($link.Title)" -ForegroundColor DarkYellow
    }
}
function Get-UserProfileManager() {
    $caURL = (Get-SPWebApplication -IncludeCentralAdministration | Where-Object -FilterScript {
            $_.IsAdministrationWebApplication -eq $true
        }).Url
    $serviceContext = Get-SPServiceContext -Site $caURL 
    return New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($serviceContext); 
}
function ConvertTo-FullXML {
    [CmdletBinding()]
    param (
        #Object to Input
        [Parameter(ValueFromPipeline)]$InputObject,
        #Name of the root document node. Defaults to "Objects"
        $RootNodeName = "Config",
        $ObjectName = $null
    )
    begin {
        [xml]$Doc = New-Object System.Xml.XmlDocument
        #Add XML Declaration
        $null = $doc.AppendChild($doc.CreateXmlDeclaration("1.0", "UTF-8", $null))
        #Add XML Root Node
        $root = $doc.AppendChild($doc.CreateElement($RootNodeName))
    }
    process {
        if ($null -eq $ObjectName) {
            $elementname = $InputObject.gettype().name
        }
        else {
            $elementname = $ObjectName
        }
        $childObject = $doc.CreateElement($elementname)
        foreach ($propItem in $InputObject.psobject.properties) {
            $propNode = $doc.CreateElement($propItem.Name)
            $propNode.InnerText = $propItem.Value
            $null = $childObject.AppendChild($propNode)
        }
        $null = $root.AppendChild($childObject)
    }
    end {
        return $doc.outerxml
    }
}
$file = "c:\temp\profilelinks.xml"
Export-UserProfileLinks $file
#  Import-UserProfileLinks $file
