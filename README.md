# Copy-UserGroups
This is a PowerShell cmdlet to copy all groupmemberships from user A to user B.  
* Option to clear all user groupmemberships of the target user first before copying. ( -ClearTargetUser )
* multiple source users, to combine groupmemberships from different sourceusers into one target user. ( -SamAccountSource john.doe,bob.smith,alice.jones )
* retains the primarygroupID property. 
* source and target domain controllers can be different (and from different domains when group names are the same) ( -Server dc1.domain.org -TargetServer dc12.domain16.org)  

## Install
Download the Copy-UserGroups.ps1 and run the file. This will check the prerequisites and load the cmdlet.

## Usage
Remove all user's groupmemberships for targetuser "test.user" first, then copy groupmemberships from john.doe to test.user  

    Copy-UserGroups -ClearTargetUser -SamAccountSource john.doe -SamAccountTarget test.user -Server dc1.domain.org 

Merg/Combine all groupmemberships from users john.doe,bob.smith,alice.jones to one user. and write the result to myuser on domain controller dc12.domain16.org

    Copy-UserGroups -SamAccountSource john.doe,bob.smith,alice.jones -SamAccountTarget myuser -Server dc1.domain.org -TargetServer dc12.domain16.org