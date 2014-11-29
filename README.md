infinite-jumping
================
This is a SourceMod plugin it lets users auto jump and/or double jump in mid air, when holding down the jump button.
AlliedModders Thread: https://forums.alliedmods.net/showthread.php?t=132391

Merging smlib updates
================
To update smlib: We will merge the latest smlib/feature-pluginmanager into addons/sourcemod.
Commit messages are squashed, that means the history of feature-pluginmanager is compressed to one commit.
```
git merge --squash -srecursive -Xsubtree=addons/sourcemod smlib/feature-pluginmanager
```
