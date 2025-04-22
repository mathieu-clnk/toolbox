## git-credentials
`git-credentials` let developer execute a script when executing the `git` command.

## sample of .gitconfig

* To redirect all https Github repositories to use the SSH protocol 
```
[url "git@github.com"]
        insteadOf = https://github.com/
```