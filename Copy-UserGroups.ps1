#Rereqs
if (!(Get-Module -ListAvailable -Name ActiveDirectory)){
    Write-Host ActiveDirectory PowerShell module not found.
    break
}
Function Copy-UserGroups {
    <#
    .SYNOPSIS
    This cmdlet copies groupmemberships from source userA to target userB. 
    .DESCRIPTION
    This cmdlet copies groupmemberships from source userA to target userB. It has an option to clear all user memberships of the target user first before copying.
    It allows for multiple source users, to combine groupmemberships from different sourceusers into one target user. 
    It will retain the primarygroup property. 
    Different source and target domain controll.ers are supported, even from different domains ( group names should be the same )
    .EXAMPLE
    Copy-UserGroups -SamAccountSource john.doe -SamAccountTarget test.user -Server dc1.domain.org -ClearTargetUser
    .EXAMPLE
    Copy-UserGroups -SamAccountSource john.doe,bob.smith,alice.jones -SamAccountTarget myuser -Server dc1.domain.org -TargetServer dc12.domain16.org
    .PARAMETER SamAccountSource
    SamaccountName (Pre2000) login name for source user
    .PARAMETER SamAccountTarget
    SamaccountName (Pre2000) login name for target user
    .PARAMETER Server
    Domain Controller (or just domain name) that is used to query source user and modify target user
    .PARAMETER TargetServer
    Optional, Domain Controller (or just domain name) that is used to modify target user
    .PARAMETER ClearTargetUser
    Before copying groups, clear all group memberships. 
    .NOTES
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String[]]$SamAccountSource,
        [Parameter(Mandatory)][String]$SamAccountTarget,
        [Parameter(Mandatory)][String]$Server,
        [Parameter()][String]$TargetServer = $Server,
        [Switch]$ClearTargetUser
    )
    $TargetUser = Get-ADUser -filter {SamAccountName -eq $SamAccountTarget} -Properties MemberOf,primaryGroupID -Server $TargetServer
    If (!$TargetUser){
        Write-Host Copy-UserGroups:Target account $SamAccountTarget not found in $TargetServer -ForegroundColor Yellow
        break
    } 
    if ($ClearTargetUser){
        if ($TargetUser.MemberOf){
            Remove-ADPrincipalGroupMembership -Identity $TargetUser.Name -MemberOf $TargetUser.MemberOf -Confirm:$false
            Write-Host Copy-UserGroups:All groupmemberships removed for $SamAccountTarget .
        } Else {
            Write-Verbose  "ClearTargetUser for $($TargetUser.Name) is not member of groups besides primary group"
        } 
    }
    $AllTargetGroups = Get-ADGroup -Filter * -Server $TargetServer
    
    foreach ($SamSource in $SamAccountSource){
        Write-Verbose "Processing User: $SamSource"
        $SourceUser = Get-ADUser -filter {SamAccountName -eq $SamSource} -Properties primaryGroupID -Server $Server
        If (!$SourceUser){
            Write-Host Copy-UserGroups:Source account $SamSource not found in $Server -ForegroundColor Yellow
            break
        } 
        #Refresh $TargetUser 
        $TargetUser = Get-ADUser -filter {SamAccountName -eq $SamAccountTarget} -Properties MemberOf,primaryGroupID -Server $TargetServer
        $arrMemberOf = [System.Collections.ArrayList]@()
        if ($TargetUser.MemberOf){
            foreach ($GroupMembershipDN in $TargetUser.MemberOf){
                $GroupMembershipDNelement = $GroupMembershipDN -split "," 
                $MemberOf = ($GroupMembershipDNelement[0]).Substring(3,($GroupMembershipDNelement[0]).Length -3)
                $arrMemberOf.Add($MemberOf) | Out-Null
            }
            if ($TargetUser.primaryGroupID -eq '513'){
                $arrMemberOf.Add("Domain Users") | Out-Null
            } 
        }

        $Sourcegroups = Get-ADPrincipalGroupMembership -Identity $SamSource -Server $Server 
        $SourcePrimaryGroup = $Sourcegroups | Where-Object{$_.SID -like "*-$($SourceUser.primaryGroupID)"}
        Write-Verbose "SourcePrimaryGroup name is $($SourcePrimaryGroup.Name) with RID $($SourceUser.primaryGroupID)"
        $TargetPrimaryGroup = $AllTargetGroups | Where-Object{$_.SID -like "*-$($TargetUser.primaryGroupID)"}
        Write-Verbose "TargetPrimaryGroup name is $($TargetPrimaryGroup.Name) with RID $($TargetUser.primaryGroupID)"
        foreach ($Sourcegroup in $Sourcegroups){
            Write-Verbose "Processing User: $SamSource Group: $($Sourcegroup.Name)"
            if ($Sourcegroup.name -eq $TargetPrimaryGroup.Name){
                Write-Verbose "Copy-UserGroups:$SamAccountTarget already a member of $($Sourcegroup.Name). It is the Primary group."
            } Else {
                If ($arrMemberOf -notcontains $Sourcegroup.Name){ 
                    $TargetGroup = $AllTargetGroups | Where-Object{$_.Name -eq $Sourcegroup.Name}
                    If ($TargetGroup){
                        Add-ADGroupMember -Identity $Sourcegroup.SamAccountName -Members $SamAccountTarget -Server $TargetServer
                        Write-Host Copy-UserGroups:Based on user $SamSource target account $SamAccountTarget added to $Sourcegroup.Name 
                    } Else {
                        Write-Host Copy-UserGroups:Based on user $SamSource $Sourcegroup.Name doesnt exist on $TargetServer -ForegroundColor Yellow 
                    }
                } Else {
                    Write-Host Copy-UserGroups:Based on user $SamSource target account $SamAccountTarget already member of $Sourcegroup.Name
                }
            }
        }
        #set Primary Group
        if ($SourceUser.primaryGroupID -ne $TargetUser.primaryGroupID){
            $TargetUser | Set-ADUser -Replace @{primaryGroupID=$SourceUser.primaryGroupID}
            Write-Verbose "Set PrimaryGroupID for $($TargetUser.Name) to $($SourceUser.primaryGroupID) which represents group: $($SourcePrimaryGroup.Name)"
        }
    }
}