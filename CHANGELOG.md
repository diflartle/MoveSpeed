# Changelog

Whoops, sorry about 2.0.2.

Blizzard made your movement speed a secret value in combat! While it still returns a number, the number for moving 102% is 7.124149 or something like that. So instead, if the call to get the movement speed fails, I just return a ??%.

Thanks, raiding.
