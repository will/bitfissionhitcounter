I found out that ad blockers were blocking http://hit-counters.net where the hit counter for http://bitfission.com was hosted. So I had to write my own hit counter. This is pretty simple. It just uses a postgres sequence and even has some rudimentary IP based protection against jokers who'd just run my hit counter up.