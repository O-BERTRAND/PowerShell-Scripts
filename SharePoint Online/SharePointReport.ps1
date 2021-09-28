#Groupe de sécurité

$creduser = Read-Host "Admin email"
$credpassword = Read-Host "Admin Password"

[securestring]$secStringPassword = ConvertTo-SecureString $credpassword -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($creduser, $secStringPassword)


Connect-AzureAD -Credential $credObject

$Table = New-Object 'System.Collections.Generic.List[System.Object]'

$Groups = Get-AzureAdGroup -All $True | Where-Object { $_.MailEnabled -eq $false -and $_.SecurityEnabled -eq $true } | Sort-Object DisplayName

$obj1 = [PSCustomObject]@{
    'Name'  = 'Security Group'
    'Count' = $Groups.count
}

$obj1

Foreach ($Group in $Groups) {
    $Users = (Get-AzureADGroupMember -ObjectId $Group.ObjectID | Sort-Object DisplayName | Select-Object -ExpandProperty DisplayName) -join ", "
    $GName = $Group.DisplayName
	
    $hash = New-Object PSObject -property @{ Name = "$GName"; Members = "$Users" }
	
    $obj = [PSCustomObject]@{
        'Name'    = $GName
        'Members' = $users
    }
	
    $table.add($obj)
}

$table | Export-Csv -Path "Groupe-SharePoint.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation


#Dossier de la bibliothèque

$SiteURL = "Site library URL"
$ListName = "List Name"

Connect-PnPOnline -Url $SiteURL -UseWebLogin

$Table2 = New-Object 'System.Collections.Generic.List[System.Object]'

$SpFolderList = Get-PnPFolderItem -FolderSiteRelativeUrl $ListName -ItemType Folder

foreach ($Folder in $SpFolderList) {

    $context = Get-PnPContext
    $file = Get-PnPFolder -Url $Folder.ServerRelativeUrl -Includes ListItemAllFields.RoleAssignments, ListItemAllFields.HasUniqueRoleAssignments
    $context.Load($file);
    $context.ExecuteQuery();

    if ($file.ListItemAllFields.HasUniqueRoleAssignments -eq $True) {
        foreach ($roleAssignments in $file.ListItemAllFields.RoleAssignments) {
            Get-PnPProperty -ClientObject $roleAssignments -Property RoleDefinitionBindings, Member
            $PermissionLevels = $roleAssignments.RoleDefinitionBindings | Select-Object -ExpandProperty Name
            $PermissionLevels = ($PermissionLevels | Where-Object { $_ -notlike "Acc*s limit*" }) -join ", "
            If ($PermissionLevels.Length -eq 0) { Continue }
            $obj2 = [PSCustomObject]@{
                'Name'  = $Folder.Name
                'Group' = $roleAssignments.Member.Title
                'Droit' = $PermissionLevels
            }
            $table2.add($obj2)
        }
    }

}

$table2 | Export-Csv -Path "Dossier-SharePoint.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation

New-HTML {
    New-HTMLTable -DataTable $table2 -Title 'SharePoint Library Rights' -HideFooter -PagingLength 25 -AlphabetSearch {
        New-TableAlphabetSearch -ColumnName 'Name'
    }
} -ShowHTML -FilePath "SharePointReport.html" -Online