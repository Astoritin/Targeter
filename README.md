## Targeter
A Magisk module to auto add new user packages to Tricky Store scope.

### Steps
1. Flash Targeter.zip in Root Manager supported Magisk modules and then reboot.
2. Targeter will work automatically as detecting the new user packages.
3. Set append mark of Tricky Store in `/data/adb/Targeter/mark.txt`. None is let Tricky Store decide which mode to use (Auto), `!` is Certificate Generate mode, `?` is Leaf Hack mode.
4. Targeter Built-in Exclude List is in `/data/adb/Targeter/exclude.txt`, every packages listed will be ignored as detecting new packages added.

### NOTICE
1. Targeter won't append the packages already exists on device before flashing Targeter or in the exclude list.
2. As for Magisk Denylist, only package name itself will be added, I don't have good stable idea to analyze the full processess of a package yet.
3. Targeter will remove the packages automatically added by Targeter currently.