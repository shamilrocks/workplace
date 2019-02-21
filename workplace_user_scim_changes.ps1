# Make sure you update the source of the CSV to the directory where it is stored.
$source = Import-CSV .\loginmethodusers.csv

#insert you access token below next to Bearer
#$accesstoken = "Bearer "
$accesstoken = "Bearer "


#Scim URI variable for getting the users
$scimuri = "https://www.facebook.com/scim/v1/Users?filter=userName%20eq%20%22"
$scimfields = "%22"

#authentication setting
$auth = "password"

#locale setting
#$locale ="en_US"
$locale = "fr_CA"
$pl = "fr_CA"

#manager id
$managerid = "100024914349334"

#Define filename for logging, will export to wherever path you execute the script from
$dt = (Get-Date).toString("yyyy-MM-dd-HH_mm", $cultureENUS)
$path = (Get-Location).Path
$filename = "$path/settings_change_$dt.csv"

#Main Loop to read each email
Foreach($value in $source){

$email = $value.email

#calling out to the SCIM API to see if the user is claimed
try{
$getuser = Invoke-RestMethod -URI $scimuri$email$scimfields -Method Get -Headers @{Authorization = $accesstoken}

#if user is claimed then process all information of user and add it to $userresources
if($getuser.totalResults -eq 1){
$userresources = $getuser.Resources | ForEach-Object -Process{$_}

#set the user id value
$uid =$userresources.id

#create the body for the API REST call to update the settings
$body = (@{
                    schemas=@("urn:scim:schemas:core:1.0","urn:scim:schemas:extension:enterprise:1.0","urn:scim:schemas:extension:facebook:starttermdates:1.0","urn:scim:schemas:extension:facebook:accountstatusdetails:1.0","urn:scim:schemas:extension:facebook:auth_method:1.0");
                    id=$uid;
                    locale=$locale;
                    preferredLanguage=$pl;
                    "urn:scim:schemas:extension:enterprise:1.0"=@{manager=@{managerId=$managerid}};
                    "urn:scim:schemas:extension:facebook:auth_method:1.0"=@{auth_method=$auth};
                    "urn:scim:schemas:extension:facebook:accountstatusdetails:1.0"=@{invited=$true};
                    active=$true
                    } | ConvertTo-Json)

#populating user variable with data from the PUT call
$user = Invoke-RestMethod -Method PUT -URI ("https://www.facebook.com/scim/v1/Users/" + $uid) -Headers @{Authorization = $accesstoken} -ContentType "application/json" -Body $body

#populating the $newuserresources with data
$newuserresources = $user | ForEach-Object -Process{$_}

#writing data for each user changed to the CSV
$newuserresources | select @{n="Original Email"; e={$email}}, @{n="Workplace ID"; e={$_.id}}, @{n="Locale"; e={$_.locale}}, @{n="Full Name"; e={$_.name.formatted}}, @{n="Auth Method Changed To"; e={$_.'urn:scim:schemas:extension:facebook:auth_method:1.0'.auth_method}} | Export-Csv -Path $filename -Append -NoTypeInformation

}


else{
#write error
write-host $email " failed" 

}

}
catch{

write-host $email " failed, error is " $_
}

}
