# SMSBackupReader
I have an adorable new family member that I get lots and lots of photos of as
SMS/MMS messages.  I would be horrified if any of these were lost due the a lost
or damaged phone.

In an attempt to avoid this, I use the great app [SMS Backup & Restore](https://play.google.com/store/apps/details?id=com.riteshsahu.SMSBackupRestore&hl=en_AU&gl=US&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1)

<a href='https://play.google.com/store/apps/details?id=com.riteshsahu.SMSBackupRestore&hl=en_AU&gl=US&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' style='width: 13em; display: block; margin-left: auto; margin-right: auto;' /></a>

**Note**: Neither I personally nor this project are affiliated with the
developers of "SMS Backup & Restore" or Google

I export the SMS messages from my Android phone to encrypted XML files that are
uploaded to my Google Drive every evening.

I then have a script that periodically downloads all these files out of my
Google Drive and removes them from Google.  This is to conserve space on my free
Google Drive account.

Now we get to the purpose of this project, extracting the content of these
encrypted XML files.  I would like to:
* Extract all the images and save them into where I store Photos (and maybe
  these sync back up to Google Photos)
* Turn the XML files into something I can read locally, without needing to
  import the backups back into my phone.  This allows me to have a local archive
  that I can reference if necessary which in turn lets me delete multiple GiB of
  MMS messages off my phone.  My phone has reached the point where one message
  conversation, which dates back several years intermittently crashes the
  messages app when accessed.  If I KNEW I could access those messages elsewhere
  I could delete them off my phone.

This project will be (a few?) bash scripts that:
* Extract all the data out of the encrypted XML files
* Images are saved to a local directory
* Messages, with the image data replaced with a reference to an image file, are
  converted to JSON and saved into an SQLite3 database
  * Duplicate messages (maybe the same message exists in multiple backups) are
    automatically ignored
* Some static HTML files are generated from the database contents

## File Format Information
The SMS Backup & Restore file format is very simple.  It's a zip compressed file
and, if you configured a password in the App, the same password can be used to
extract a simple XML file from the zip file.

Binary content (e.g. Images) are base64 encoded into an element within the XML
document.

TODO: Add some sanitized examples

## Usage
The scripts make use of some common *nix utilities which must be installed
before the script will function.  For Ubuntu:
```
sudo apt install jq xmlstarlet python3-pip sqlite3-pcre sqlite3
sudo pip install yq
```

### Configuration
Configuration is (or will be) stored in the SQLite3 database.  To set a
configuration value:
```
extracter.sh config set <name> <value>
```

The only configuration value at present is your local international dialing code
so that numbers such as "+61412345678" and "0412345678" can be merged into a
single contact thread.  To set this value:
```
extracter.sh config set my_intl_code 61
```

I'm sure there will be more configuration values added in the future.

### Parsing XML files
At this time, I don't have the extraction from zip using a password implemented
yet so the script expects to be just given an extracted XML file.
```
extracter.sh parse /path/to/file.xml
```

### Generating Static HTML files
```
extracter.sh generate html
```

## Bash script?
Yeah, it's not very portable, etc. but I hope that this project will be simple
enough to have functional within a few days of effort.  Also,
[Bash is my hammer](https://en.wikipedia.org/wiki/Law_of_the_instrument#Computer_programming).

## Alternatives
The fine developers of SMS Backup & Restore do provide some other options for
reading the files they create.  More information can be found here: https://synctech.com.au/sms-backup-restore/view-or-edit-backup-files-on-computer/

Some Notes:
* "View the backup data using a web browser" - Your browser will struggle if
  your backup file is several GiB
* "Threaded view for SMS Messages" - Your browser will still struggle if your
  backup file is several GiB and, while this method looks prettier, it doesn't
  seem to support MMS messages.
* "View/Edit messages using MS Excel" - No thanks. :-)
