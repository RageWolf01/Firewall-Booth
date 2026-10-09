# push-to-github.ps1 — publish this project to GitHub.
#
# Run it from the project folder, after installing Git for Windows:
#     winget install --id Git.Git -e
# then open a NEW terminal (so git is on PATH) and:
#     .\push-to-github.ps1
#
# Why this is a script and not something already done for you: the machine this
# project was developed on has no `git` installed and its outbound HTTPS is blocked,
# so nothing could be pushed from there. This does the whole job in one step on a
# machine that has both.
#
# It is safe to re-run. If the repo already exists locally it just commits and pushes.

[CmdletBinding()]
param(
    # Change these if you want the commit to be attributed to a different identity.
    [string]$UserName  = "RageWolf01",
    [string]$UserEmail = "",
    [string]$Remote    = "https://github.com/RageWolf01/Firewall-Booth.git",
    [string]$Branch    = "main"
)

$ErrorActionPreference = "Stop"

function Say($m) { Write-Host "  $m" }
function Head($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }

# ---------------------------------------------------------------- preflight ---

Head "Checking for git"
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "`n  git is not installed (or not on PATH)." -ForegroundColor Yellow
    Write-Host "  Install it with:  winget install --id Git.Git -e"
    Write-Host "  Then open a NEW terminal and run this script again."
    exit 1
}
Say "git $((git --version) -replace '^git version ','') at $($git.Source)"

if (-not (Test-Path "project.godot")) {
    Write-Host "`n  This does not look like the project root: no project.godot here." -ForegroundColor Yellow
    Write-Host "  cd to the folder that contains project.godot and run again."
    exit 1
}
Say "project.godot found - this is the project root"

# ---------------------------------------------------------------- identity ----

Head "Git identity"
$currentName  = (git config --global user.name)  2>$null
$currentEmail = (git config --global user.email) 2>$null
if (-not $currentName)  { git config --global user.name  $UserName; Say "set user.name  = $UserName" }
else                    { Say "user.name  already $currentName" }
if (-not $currentEmail) {
    if (-not $UserEmail) {
        # GitHub's noreply address keeps your real email out of the commit history.
        $UserEmail = "$UserName@users.noreply.github.com"
    }
    git config --global user.email $UserEmail
    Say "set user.email = $UserEmail"
} else { Say "user.email already $currentEmail" }

# ---------------------------------------------------------------- repo --------

Head "Initialising the repository"
if (Test-Path ".git") {
    Say "already a git repo - reusing it"
} else {
    git init -b $Branch | Out-Null
    Say "git init on branch $Branch"
}

Head "Staging files"
# .gitignore keeps out .godot/, the addon self-update cache and verification/.
git add -A
$staged = (git diff --cached --name-only) 2>$null
$count  = if ($staged) { ($staged | Measure-Object).Count } else { 0 }
Say "$count files staged"
if ($count -eq 0) {
    Say "nothing to commit - everything is already committed"
} else {
    # Show what is NOT going in, so a surprise exclusion is visible rather than silent.
    $ignored = (git status --porcelain --ignored) 2>$null |
        Where-Object { $_ -match '^!!' } | Select-Object -First 6
    if ($ignored) {
        Say "ignored (first few):"
        $ignored | ForEach-Object { Write-Host "      $($_ -replace '^!! ','')" }
    }
    git commit -m "Firewall Booth: 2D pixel-art first-person inspection sim" | Out-Null
    Say "committed"
}

# ---------------------------------------------------------------- remote ------

Head "Connecting the remote"
$existing = (git remote) 2>$null
if ($existing -contains "origin") {
    $url = (git remote get-url origin) 2>$null
    if ($url -ne $Remote) { git remote set-url origin $Remote; Say "origin repointed to $Remote" }
    else                  { Say "origin already $Remote" }
} else {
    git remote add origin $Remote
    Say "origin added: $Remote"
}

# ---------------------------------------------------------------- push --------

Head "Pushing"
Write-Host "  A browser window or credential prompt may appear. Sign in as $UserName." -ForegroundColor Yellow
try {
    git push -u origin $Branch
} catch {
    Write-Host "`n  Push failed. The usual causes, in order:" -ForegroundColor Yellow
    Write-Host "    1. Not signed in. Run:  git push -u origin $Branch   and complete the prompt."
    Write-Host "    2. The remote already has commits (e.g. a README made on GitHub)."
    Write-Host "       Merge them first:"
    Write-Host "         git pull --rebase origin $Branch"
    Write-Host "         git push -u origin $Branch"
    Write-Host "    3. Auth method: use a Personal Access Token as the password, or install"
    Write-Host "       GitHub CLI (winget install --id GitHub.cli -e) and run:  gh auth login"
    exit 1
}

Head "Done"
Say "View it at https://github.com/RageWolf01/Firewall-Booth"
