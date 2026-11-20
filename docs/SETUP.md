# Plantagonist setup guide

Everything set up for Plantagonist so far, how to check it still works, and
how to recreate each key or token if one is lost or expires. Written for a
Mac. Commands go in Terminal unless a step says otherwise.

Set up on 2026-11-20.

## Contents

1. [What we have](#1-what-we-have)
2. [GitHub repo and Mac tools](#2-github-repo-and-mac-tools)
3. [Syncing code into Studio with Rojo](#3-syncing-code-into-studio-with-rojo)
4. [The published place](#4-the-published-place)
5. [The .env file (where keys live)](#5-the-env-file-where-keys-live)
6. [Roblox Open Cloud API key](#6-roblox-open-cloud-api-key)
7. [Blender for 3D models](#7-blender-for-3d-models)
8. [Cloudflare image generation (Flux)](#8-cloudflare-image-generation-flux)
9. [Starting another game](#9-starting-another-game)
10. [Quick fixes](#10-quick-fixes)

## 1. What we have

| Piece | Where it lives | Notes |
| --- | --- | --- |
| Code repo | github.com/wyliechat-del/plantagonist (private) | Cloned to `~/plantagonist` on the Mac |
| Tools | `rokit.toml` in the repo | Rojo 7.5.1, Selene 0.29.0, StyLua 2.1.0, Lune 0.10.1 |
| Rojo plugin | `~/Documents/Roblox/Plugins/RojoManagedPlugin.rbxm` | Connects Studio to `rojo serve` |
| Roblox place | Place 131103195294317, experience (universe) 10777967103 | Private, owned by your Roblox account |
| Open Cloud key | Named `plantagonist-dev` in Creator Hub | Stored only in `~/plantagonist/.env` |
| Blender | Blender 5.0.1 in Applications | Models in `models/`, guide in `docs/blender.md` |
| Cloudflare token | Named `plantagonist-images` in Cloudflare | Stored only in `~/plantagonist/.env` |

Two rules cover every key and token:

- Keys go only in `~/plantagonist/.env`. Git ignores that file, so it is never uploaded.
- Never paste a key into a chat, a screenshot or a commit. If one leaks,
  regenerate it (steps below) and the old one stops working.

## 2. GitHub repo and Mac tools

### What was done

- The repo `plantagonist` was created on GitHub as **Private**, with no README,
  .gitignore or licence ticked. Claude pushed the starting files.
- Git was already on the Mac (`git --version` printed 2.50.1).
- Rokit was installed, and it installed the tools pinned in `rokit.toml`.
- The repo was cloned to `~/plantagonist`. The Mac already had a GitHub
  sign-in saved, so it did not ask for a password.
- There is no Homebrew on the Mac, so the GitHub CLI (`gh`) is not used.

### Redo it on a new Mac

1. Open Terminal and run `git --version`. If a box asks to install developer
   tools, click Install and wait for it to finish.
2. Install Rokit with the one-line command from
   <https://github.com/rojo-rbx/rokit#installation>.
3. Quit Terminal fully (Cmd+Q) and open it again, so it can find Rokit.
4. Download the repo:
   ```sh
   cd ~
   git clone https://github.com/wyliechat-del/plantagonist.git
   ```
   If it asks for a username and password, use the token steps below.
5. Install the tools:
   ```sh
   cd ~/plantagonist
   rokit install
   ```
   Answer yes if it asks whether to trust a tool.
6. Check it worked: `rojo --version` should print `Rojo 7.5.1`.

### GitHub token (only if Git asks for a password)

GitHub no longer accepts your account password in Terminal. Use a
fine-grained token instead:

1. Open <https://github.com/settings/personal-access-tokens/new>.
2. Name it `plantagonist mac` and pick an expiry (90 days is fine).
3. Under **Repository access**, choose **Only select repositories** and pick
   `plantagonist`.
4. Under **Permissions**, set **Contents** to **Read and write**.
5. Click **Generate token** and copy it. GitHub shows it only once.
6. Run the `git clone` (or `git push`) again. For **Username** type
   `wyliechat-del`. For **Password** paste the token and press Return.
   Nothing shows while you paste; that is normal.

The Mac saves the token in Keychain, so you only do this once. When the token
expires, Git asks again: make a new token with the same steps.

### Checks

The repo has four checks: Rojo build, tests (Lune), lint (Selene) and format
(StyLua). Run them all with:

```sh
cd ~/plantagonist
./scripts/check.sh
```

GitHub runs the same checks on every push and pull request
(`.github/workflows/checks.yml`).

## 3. Syncing code into Studio with Rojo

### Install the Studio plugin (once)

1. Open Roblox Studio at least once, so its folders exist.
2. In Terminal:
   ```sh
   mkdir -p ~/Documents/Roblox/Plugins
   cd ~/plantagonist
   rojo plugin install
   ```
   No message means it worked. `ls ~/Documents/Roblox/Plugins` should show
   `RojoManagedPlugin.rbxm`.
3. Quit Studio (Cmd+Q) and reopen it.

Do not also install Rojo from the Creator Store, or you get two Rojo buttons.
Studio may show a popup offering a newer Rojo (such as 7.7.1). Ignore it: the
repo pins 7.5.1, and upgrading is a separate change.

### Connect each time you work

1. In Terminal:
   ```sh
   cd ~/plantagonist && rojo serve
   ```
   Leave this window open. It listens on port 34872. Use a new tab
   (Cmd+T) for any other commands, because this one is busy.
2. In Studio, open the Plantagonist place.
3. Plugins tab > **Rojo** > **Connect**. Click **Accept** if it lists files to sync.
4. Press Play. Window > Output (or Cmd+Shift+O) should show
   `[Plantagonist] server started`.

Edit code in the files in `src/`, never inside Studio. Changes appear in Studio
when you save.

## 4. The published place

| | |
| --- | --- |
| Name | Plantagonist |
| Place ID | 131103195294317 |
| Experience (universe) ID | 10777967103 |
| Who can play | Only you and collaborators (not released publicly) |
| Team Create | On (Studio's default) |

It was published from Studio with File > **Publish to Roblox** > new
experience, name Plantagonist, everything else on the defaults.

Because Team Create is on, Studio reopens the place as a live editing session
after publishing, and that disconnects Rojo. Click **Connect** in the Rojo
panel again (with `rojo serve` running).

To find the IDs again: <https://create.roblox.com> > Creations > Plantagonist.
The experience ID is in the page address; the place ID is under Places.

## 5. The .env file (where keys live)

`~/plantagonist/.env` holds every key and ID for this game. When everything is
set up it has these lines (real values in place of the dots):

```sh
ROBLOX_OPEN_CLOUD_API_KEY=...
ROBLOX_UNIVERSE_ID=10777967103
ROBLOX_PLACE_ID=131103195294317
CLOUDFLARE_ACCOUNT_ID=...
CLOUDFLARE_API_TOKEN=...
```

`.env.example` in the repo lists the same names with no values.

Fill it from Terminal, not TextEdit. TextEdit edits did not save reliably, and
pasting into Terminal with `read -s` keeps the key off the screen.

To check what is in it without showing any key (prints only lengths):

```sh
cd ~/plantagonist && set -a && source .env && set +a && echo "universe=$ROBLOX_UNIVERSE_ID place=$ROBLOX_PLACE_ID roblox_key_length=${#ROBLOX_OPEN_CLOUD_API_KEY} cloudflare_account_length=${#CLOUDFLARE_ACCOUNT_ID} cloudflare_token_length=${#CLOUDFLARE_API_TOKEN}"
```

A length of 0 means that line is missing or empty.

## 6. Roblox Open Cloud API key

The key lets scripts on the Mac talk to Roblox (for example, publish the place
from a file) without opening Studio. It has no access to GitHub.

| Setting | Value |
| --- | --- |
| Name | `plantagonist-dev` |
| Permissions | `universe:read` and `universe-places:write`, both limited to the Plantagonist experience |
| Accepted IP addresses | `0.0.0.0/0` (any address) |
| Expiration | None set. Roblox still disables a key after 60 days without use. |

### Create a new key

1. Go to <https://create.roblox.com> > Dashboard > **Open Cloud** >
   **API Keys** > **Create API Key**.
2. Name: `plantagonist-dev`. If the name is taken, use `plantagonist-dev-2`.
3. Under **Access Permissions**, add the API system **universe-places**,
   choose the Plantagonist experience, and pick **write**.
4. Add the API system **universe**, choose Plantagonist, and pick **read**.
   Read lets you test the key without changing anything.
5. Under **Accepted IP Addresses**, add `0.0.0.0/0`.
6. Leave the expiration empty and click **Save & Generate Key**.
7. Copy the key straight away. Roblox shows it only once.
8. Save it (step below).

### Regenerate an existing key

Use this if the key was lost, leaked, or stopped working after 60 days unused.

1. Creator Hub > Open Cloud > **API Keys**, click `plantagonist-dev`.
2. Click **Regenerate Key** and copy the new key. The old one stops working.
3. Save it (step below).

### Save the key in .env

This removes the old key line (if any) and adds the new one, leaving the other
lines alone:

```sh
cd ~/plantagonist && touch .env && sed -i '' '/^ROBLOX_OPEN_CLOUD_API_KEY=/d' .env && read -s "k?Paste Roblox key, then Return: " && echo "ROBLOX_OPEN_CLOUD_API_KEY=$k" >> .env && unset k && echo && echo saved
```

When it shows `Paste Roblox key, then Return:`, press Cmd+V, then Return.
Nothing shows while you paste. It prints `saved`.

If the two ID lines are missing too (for example on a new Mac), add them:

```sh
cd ~/plantagonist && printf 'ROBLOX_UNIVERSE_ID=10777967103\nROBLOX_PLACE_ID=131103195294317\n' >> .env
```

### Test the key

This prints one number and never shows the key:

```sh
cd ~/plantagonist && set -a && source .env && set +a && curl -s -o /dev/null -w "%{http_code}\n" -H "x-api-key: $ROBLOX_OPEN_CLOUD_API_KEY" https://apis.roblox.com/cloud/v2/universes/$ROBLOX_UNIVERSE_ID
```

| Number | Meaning | What to do |
| --- | --- | --- |
| 200 | It works | Nothing |
| 401 | Roblox did not accept the key | The paste got cut off or picked up a space, or the key expired. Save it again, or regenerate it. |
| 403 | The key works but lacks permission | Check `universe:read` is set for Plantagonist on the key. |
| 404 | Roblox could not find the experience | `ROBLOX_UNIVERSE_ID` is missing or wrong in `.env`. Run the check command in section 5. |
| 000 | The command did not reach Roblox | A typo, or no internet. |

### Optional later: uploading models and images without Studio

Right now models and images are uploaded through Studio. To upload them from a
script instead, edit the key in Creator Hub and add the API system **assets**
with **read** and **write** (`asset:read`, `asset:write`). Saving the edited
key does not change the key text, so `.env` stays the same. Run the test again
afterwards.

## 7. Blender for 3D models

Added in pull request #1. Full guide: [docs/blender.md](blender.md).

### What was done

- Blender 5.0.1 installed from <https://www.blender.org/download/> into
  Applications. Command-line path:
  `/Applications/Blender.app/Contents/MacOS/Blender`.
- Optional shortcut in `~/.zshrc`:
  ```sh
  alias blender=/Applications/Blender.app/Contents/MacOS/Blender
  ```
- Tested end to end: a test cube went from Blender to the export script to
  Studio and arrived as a 2 x 2 x 2 stud MeshPart.

### The workflow

1. Make a new file in Blender. In Properties > **Scene** tab > Units, set
   **Unit System** to **None**. Now 1 Blender unit = 1 stud.
2. Save it as `models/<Name>.blend` in the repo.
3. Export and check it from Terminal:
   ```sh
   cd ~/plantagonist
   blender --background models/<Name>.blend --python scripts/blender/export_roblox.py
   ```
   It lists every mesh with its triangle count and size, warns over 10,000
   triangles, and fails (writes nothing) over 20,000. If it passes it writes
   `models/export/<Name>.fbx`. Exports are not committed; the `.blend` is.
4. In Studio: **Import 3D**, pick the `.fbx` from `models/export/`, keep
   **Scale Unit** on **Stud**, and click **Import**.

Claude can run step 3 for you on the Mac and drive Studio's menus, but you
have to pick the file and click Import yourself. macOS treats the file picker
and the import window as a separate app that Claude cannot click in.

## 8. Cloudflare image generation (Flux)

Added in pull request #2. Full guide: `docs/images.md`.

`scripts/images/generate.py` sends a text prompt to Cloudflare Workers AI
(model `@cf/black-forest-labs/flux-1-schnell`) and saves a 1024 x 1024 JPEG in
`art/generated/` (Git ignores that folder). It talks to Cloudflare's API
directly, so no Cloudflare Worker is needed. It reads the two values from
`.env` by itself.

| Setting | Value |
| --- | --- |
| Token name | `plantagonist-images` |
| Made from | The **Workers AI** template (Workers AI read and edit) |
| Expiry | None |
| Stored in | `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` in `~/plantagonist/.env` |

Workers AI has a free daily allowance; past that, Cloudflare bills per use.

### Recreate the token

1. Sign in at <https://dash.cloudflare.com>.
2. Profile icon (top right) > **My Profile** > **API Tokens**.
3. If the old `plantagonist-images` token is still listed, click its **...**
   menu and pick **Roll** to get a new value, or **Delete** it and make a new one.
4. To make a new one: **Create Token**, then next to **Workers AI** click
   **Use template** > **Continue to summary** > **Create Token**. Name it
   `plantagonist-images`.
5. Copy the token. Cloudflare shows it once.
6. Save it (removes the old line, adds the new one):
   ```sh
   cd ~/plantagonist && touch .env && sed -i '' '/^CLOUDFLARE_API_TOKEN=/d' .env && read -s "t?Paste Cloudflare token, then Return: " && echo "CLOUDFLARE_API_TOKEN=$t" >> .env && unset t && echo && echo saved
   ```

### Account ID (if it is missing from .env)

1. In the Cloudflare dashboard, on the Account home page, click the **...**
   next to your account name and pick **Copy account ID**.
2. Save it:
   ```sh
   cd ~/plantagonist && sed -i '' '/^CLOUDFLARE_ACCOUNT_ID=/d' .env && read "a?Cloudflare account ID: " && echo "CLOUDFLARE_ACCOUNT_ID=$a" >> .env && unset a && echo saved
   ```

### Test it

```sh
cd ~/plantagonist
python3 scripts/images/generate.py "a cheerful cartoon sunflower, game icon, flat colors"
```

It prints `Saved art/generated/....jpg`. Open the file to look at it.

Things to know:

- Run it in Terminal on the Mac. Claude's cloud workspace cannot reach
  Cloudflare's API, so Claude runs it through a Remote Control session on the
  Mac when needed.
- Flux Schnell on Workers AI does not accept a seed, so the same prompt gives
  a new picture each time. Keep the ones you like.
- `--steps 1-8` trades speed for detail (default 4). `--name` sets the file name.

## 9. Starting another game

Short answer: most of this copies over. The tools on the Mac, Blender and the
Cloudflare token are already done and work for any game. Each new game needs
its own repo, its own published place, its own Roblox key (or this one
widened) and its own `.env`. Expect about 20 to 30 minutes, mostly in Creator
Hub and Studio.

### Reuse as is

| What | Why it carries over |
| --- | --- |
| Git, Rokit and the GitHub sign-in on the Mac | Installed once per Mac |
| Rojo plugin in Studio | One plugin works for every project |
| Blender 5.0.1 | Installed once per Mac |
| Cloudflare account ID and `plantagonist-images` token | Tied to your Cloudflare account, not to a game. Copy the two lines into the new `.env`. (Renaming the token to something general is fine.) |

### Copy from this repo

| What | Notes |
| --- | --- |
| Folder layout (`src/shared/Config`, `Rules`, `Remotes.luau`, `src/server`, `src/client`, `tests/`) | Keep the structure, clear out game code |
| Tool configs: `rokit.toml`, `selene.toml`, `tests/selene.toml`, `stylua.toml`, `.vscode/` | Copy unchanged |
| `.github/workflows/checks.yml` and `scripts/check.sh` | Copy unchanged |
| `scripts/blender/export_roblox.py`, `scripts/images/generate.py` | Copy unchanged |
| `.gitignore`, `.env.example` | Copy unchanged |
| `CLAUDE.md`, `README.md`, `docs/` | Copy, then change the game name |

The easiest way: on GitHub, open the plantagonist repo > **Settings** > tick
**Template repository**. Then new games start from **Use this template** and
get all of the above in one go. Claude can then strip out the
Plantagonist-specific code.

### New for every game

1. **Repo.** Create it on GitHub (private, nothing ticked) or from the
   template. Add it to the Claude project so Claude can push to it. If you use
   a GitHub fine-grained token on the Mac, add the new repo to the token's
   selected repositories (or make a new token).
2. **Rojo project name.** Change the `"name"` in `default.project.json`.
3. **Clone and install** on the Mac: `git clone ...`, `cd <game>`,
   `rokit install`.
4. **Publish the place.** In Studio with Rojo connected: File > Publish to
   Roblox > new experience, private. Note the new place ID and experience ID.
5. **Open Cloud key.** Either:
   - Make a new key for the new game (recommended; same steps as section 6
     with the new experience picked), or
   - Edit `plantagonist-dev` and add the new experience to both permission
     rows. One key then works for both games, and a leak affects both.
6. **New `.env`** in the new repo folder, with the new key, the new
   `ROBLOX_UNIVERSE_ID` and `ROBLOX_PLACE_ID`, and the same two Cloudflare lines.
   Use the `read -s` commands above, run in the new folder.
7. **Test** with the 200 test command and `./scripts/check.sh`.

## 10. Quick fixes

| Problem | Fix |
| --- | --- |
| Typed commands do nothing in Terminal | That tab is running `rojo serve`. Open a new tab with Cmd+T. |
| "Address already in use" from `rojo serve` | Rojo is already running in another tab. Just click Connect in Studio. |
| Rojo disconnected after publishing or reopening the place | Click Connect in the Rojo panel again, with `rojo serve` running. |
| `rojo plugin install` fails | Open Studio once, run `mkdir -p ~/Documents/Roblox/Plugins`, try again. |
| No Output window in Studio | Window > Output, or Cmd+Shift+O. |
| Git asks for a password | Use a GitHub token (section 2). |
| Roblox test returns 401 | Regenerate the key and save it again (section 6). |
| Image script says a value is missing | Add the missing Cloudflare line to `.env` (section 8). |
