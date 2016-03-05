#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/skype-detect.git && cd skype-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

name=$(echo "Skype")
changes=$(echo "https://support.skype.com/en/faq/FA34509/what-s-new-in-skype-for-windows-desktop")

linklist=$(cat <<EOF
http://www.skype.com/go/getskype-full
http://www.skype.com/go/getskype-msi
extra line
EOF
)

printf %s "$linklist" | while IFS= read -r link
do {

rm $tmp/* -rf > /dev/null

echo Downloading link information
wget -S --spider "$link" -o $tmp/$appname.log
echo

#get full url of exe or msi installer
url=$(grep -A99 "^Resolving" $tmp/$appname.log | sed "s/http/\nhttp/g;s/exe/exe\n/g;s/msi/msi\n/g" | grep "http.*\.exe\|http.*\.msi" | head -1)
echo $url | grep "http.*SkypeSetup"
if [ $? -eq 0 ]; then
echo

#check if this url is in database
grep "$url" $db
if [ $? -ne 0 ]; then

echo new version detected!
echo

#set file name
filename=$(echo $url | sed "s/^.*\///g")

echo downloading file..
wget $url -O$tmp/$filename
echo

echo searching exact version number..
7z x $tmp/$filename -y -o$tmp > /dev/null

if [ -f "$tmp/Skype.exe" ]; then
echo extracting Skype.exe
7z x $tmp/Skype.exe -y -o$tmp > /dev/null
fi

version=$(grep -B99 -m1 "<dependency>" $tmp/.rsrc/0/MANIFEST/1 | sed "s/\d034/\n/g" | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+")
echo $version | grep "^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+"
if [ $? -eq 0 ]; then
echo

case "$filename" in
*msi)
businessurl=$(echo "$url")
businessmd5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
businesssha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
rm $tmp/* -rf > /dev/null
wget -S --spider -o $tmp/$appname.log "http://download.skype.com/msi/SkypeSetup_`echo $version`.msi"
url=$(sed "s/http/\nhttp/g;s/\.msi/\.msi\n/g" $tmp/$appname.log | grep "http.*\.msi" | head -1)
echo $url | grep "http.*SkypeSetup"
if [ $? -eq 0 ]; then
filename=$(echo $url | sed "s/^.*\///g")
wget $url -O$tmp/$filename
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 5120000 ]; then

echo "$businessurl">> $db
echo "$version">> $db
echo "$businessmd5">> $db
echo "$businesssha1">> $db
echo >> $db

else
echo $filename to small
fi

else
echo $filename not hosting
fi
;;
esac

#if previous steps fails the setup file is already deleted
if [ -f "$tmp/$filename" ]; then
echo

versionforchangelog=$(echo "$version" | sed "s/\.[0-9]\+//2;s/\.[0-9]\+//2;s/^/Skype /")
wget -qO- "$changes" | grep -A20 "$versionforchangelog" | grep -B99 -m2 "</tr>" | grep -A99 "<ul>" | grep -B99 -m1 "</ul>" | sed -e "s/<[^>]*>//g" | sed "s/^[ \t]*//g" | grep -v "^$" | grep "\w" | sed "s/^/- /" > $tmp/change.log

#check if even something has been created
if [ -f $tmp/change.log ]; then

#calculate how many lines log file contains
lines=$(cat $tmp/change.log | wc -l)
if [ $lines -gt 0 ]; then
echo change log found:
echo
cat $tmp/change.log
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$url">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#create unique filename for google upload
case "$filename" in
*exe)
newfilename=$(echo $filename | sed "s/\.exe/_`echo $version`\.exe/")
mv $tmp/$filename $tmp/$newfilename
;;
*msi)
newfilename=$(echo $filename)
;;
esac

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $newfilename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$newfilename"
echo
fi

case "$filename" in
*msi)
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version msi" "$url 
https://c7b4a45f0a3bc4eb45648fd482921771430a8d95.googledrive.com/host/0B_3uBwg3RcdVMEZGNlUxeVd0dWM/$newfilename 
$md5
$sha1

Skype for Business:
$businessurl 
$businessmd5
$businesssha1

Change log:
`cat $tmp/change.log`"
} done
echo
;;
*exe)
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version" "$url 
https://c7b4a45f0a3bc4eb45648fd482921771430a8d95.googledrive.com/host/0B_3uBwg3RcdVMEZGNlUxeVd0dWM/$newfilename 
$md5
$sha1

Change log:
`cat $tmp/change.log`"
} done
echo
;;
esac

else
#changes.log file has created but changes is mission
echo changes.log file has created but changes is mission
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log file has created but changes is mission: 
$version 
$changes "
} done
fi

else
#changes.log has not been created
echo changes.log has not been created
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log has not been created: 
$version 
$changes "
} done
fi

else
#can not find skype setup file anymore
echo can not find skype setup file anymore
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "can not find skype setup file anymore: 
$link 
$url "
} done
fi

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$link 
$url "
} done
fi

else
#file is already in database
echo file is already in database
fi

else
#url do not match standard pattern
echo url do not match sdandart pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "url do not match sdandart pattern: 
$link 
$url "
} done
fi

} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
