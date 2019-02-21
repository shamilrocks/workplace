$source = Import-CSV .\emailchange.csv
#insert you access token below next to Bearer
$accesstoken = "Bearer "
$scimuri = "https://www.facebook.com/scim/v1/Users?filter=userName%20eq%20%22"
$scimfields = "%22"

#Define filename
$dt = (Get-Date).toString("yyyy-MM-dd-HH_mm", $cultureENUS)
$path = (Get-Location).Path
$filename = "$path/email_change_$dt.csv"

#Main Loop to read each email and new email in the imported CSV
Foreach($value in $source){
$email = $value.email
$newemail = $value.newemail

#uncomment to troubleshoot and verify emails are being read
#write-host  "Source Email is "$email
#write-host "Target Email is "$newemail

#calling out to the SCIM API to see if the user is claimed
try{
$getuser = Invoke-RestMethod -URI $scimuri$email$scimfields -Method Get -Headers @{Authorization = $accesstoken}

#if user is claimed then process all information of user and add it to $userresources
if($getuser.totalResults -eq 1){
$userresources = $getuser.Resources | ForEach-Object -Process{$_}

#uncomment to troubleshoot if you are not getting values for the $userresources
#write-host $userresources.id $userresources.emails.value

#set the user id value
$uid =$userresources.id

#create the body for the API REST call to update the user email
$body = (@{
                    schemas=@("urn:scim:schemas:core:1.0","urn:scim:schemas:extension:enterprise:1.0","urn:scim:schemas:extension:facebook:starttermdates:1.0","urn:scim:schemas:extension:facebook:accountstatusdetails:1.0","urn:scim:schemas:extension:facebook:auth_method:1.0");
                    id=$uid;
                    userName=$newemail;
                    emails=@{value=$newemail};
                    active=$true
                    } | ConvertTo-Json)

#populating user variable with data from the PUT call
$user = Invoke-RestMethod -Method PUT -URI ("https://www.facebook.com/scim/v1/Users/" + $uid) -Headers @{Authorization = $accesstoken} -ContentType "application/json" -Body $body

#uncomment to troubleshoot if the $user variable is populated
#write-host $uid " " $email " has been changed to "  $newemail

#populating the $newuserresources with data
$newuserresources = $user | ForEach-Object -Process{$_}

#writing data for each user changed to the CSV
$newuserresources | select @{n="Original Email"; e={$email}}, @{n="New Email"; e={$_.emails.value}}, @{n="Workplace ID"; e={$_.id}}, @{n="Full Name"; e={$_.name.formatted}}, @{n="Error Message"; e={$_}} | Export-Csv -Path $filename -Append -NoTypeInformation

}

else{
#goal is to write whatever the failure is to the csv
#write-host "error"
$elseerror = $email + " name doesn't exist"
$elseerror | select @{n="Original Email"; e={$email}}, @{n="New Email"; e={""}}, @{n="Workplace ID"; e={""}}, @{n="Full Name"; e={""}}, @{n="Error Message"; e={$_}} | Export-Csv -Path $filename -Append -NoTypeInformation
}

}
catch{
#goal is to write whatever the failure is to the csv
$catcherror = $email + $_
$catcherror | select @{n="Original Email"; e={$email}}, @{n="New Email"; e={""}}, @{n="Workplace ID"; e={""}}, @{n="Full Name"; e={""}}, @{n="Error Message"; e={$_}} | Export-Csv -Path $filename -Append -NoTypeInformation
#write-host $email " failed, error is " $_
}

}
