## Targeter
A Magisk module to auto add new user packages to Tricky Store scope / 一个用于将新软件包名加入 Tricky Store 作用域的 Magisk 模块

### Steps / 步骤
1. Flash Targeter.zip in Root Manager supported Magisk modules and then reboot the device.
2. Targeter will work automatically as detecting the new user packages.
3. Set append mark of Tricky Store in `/data/adb/Targeter/mark.txt`. None is let Tricky Store decide which mode to use (Auto), `!` is Certificate Generate mode, `?` is Leaf Hack mode.
4. Targeter Built-in Exclude List is in `/data/adb/Targeter/exclude.txt`, every packages listed will be ignored as detecting new packages added.
***
1. 在支持模块系统的 Root 管理器刷入 Targeter.zip 后重启设备。
2. Targeter 将在检测到新的用户包名时自动工作。
3. 在 `/data/adb/Targeter/mark.txt` 中设置将新包名追加到 Tricky Store 的标记（后缀），为空则是让 Tricky Store 决定使用何种模式 (自动)，设定为 `!` 则是证书生成模式，为 `?` 则是根入侵模式。
4. Targeter 的内置排除列表位于 `/data/adb/Targeter/exclude.txt`，在该清单中罗列的包名将在检测到新包名被安装的时候被忽略（不做处理）。

### NOTICE / 注意
1. Targeter won't append those packages which already exists on device before flashing Targeter or in the exclude list to Tricky Store scope or Magisk Denylist.
2. As for Magisk Denylist, only package name itself will be added, I don't have good stable idea to analyze the full processess of a package yet.
3. Targeter will remove the packages when detecting packages uninstalled if they are automatically added by Targeter currently.
***
1. Targeter 不会将在刷入 Targeter 之前已存在的包名或在内置排除列表内的包名追加到 Tricky Store 的作用域和 Magisk 的排除列表。
2. 目前仅包名自身会被同步添加到 Magisk 的排除列表，我面前没有什么解析一个包的全部进程名的方案。
3. 当检测到包名被卸载时，Targeter 将移除那些由 Targeter 自动添加的包名。