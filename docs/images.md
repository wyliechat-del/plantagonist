# Generated images: drafting art with Cloudflare Flux

`scripts/images/generate.py` sends a text prompt to Cloudflare Workers AI
(model `@cf/black-forest-labs/flux-1-schnell`) and saves the picture. Use it
for texture ideas, item icons, UI art and concept images.

Workers AI has a free daily allowance; past that, Cloudflare bills per use.

## Set up (once)

You need a Cloudflare account ID and an API token in `~/plantagonist/.env`.

1. Sign in at <https://dash.cloudflare.com>.
2. Copy your account ID: on the Account home page, click the **...** menu
   next to your account name and pick **Copy account ID**.
3. In Terminal, save it (paste when asked, then press Return):
   ```sh
   cd ~/plantagonist
   read "?Cloudflare account ID: " A && echo "CLOUDFLARE_ACCOUNT_ID=$A" >> .env && unset A
   ```
4. Back in the dashboard: profile icon (top right) > **My Profile** >
   **API Tokens** > **Create Token**. Next to **Workers AI**, click
   **Use template**, then **Continue to summary** > **Create Token**.
5. Copy the token (Cloudflare shows it once) and save it. Nothing appears on
   screen while you paste; that is normal:
   ```sh
   read -s "?Cloudflare API token: " T && echo "CLOUDFLARE_API_TOKEN=$T" >> .env && unset T; echo
   ```
6. Test it:
   ```sh
   python3 scripts/images/generate.py "a cheerful cartoon sunflower, game icon, flat colors"
   ```
   It prints `Saved art/generated/....jpg`. Open the file to look at it.

Never paste the token into chat or commit `.env`.

## Making images

```sh
python3 scripts/images/generate.py "PROMPT" [--name NAME] [--steps 1-8]
```

- Output goes to `art/generated/` (Git ignores it). Each `.jpg` has a `.json`
  beside it with the prompt, steps and model.
- Running the same prompt again gives a new variation each time. Flux Schnell
  on Workers AI has no seed setting, so a result can't be repeated exactly:
  keep the images you like.
- `--steps` trades speed for detail. 4 is the default, 8 the maximum.
- Images come out 1024 x 1024.

Prompt tips for game art:
- Icons: "game icon of X, centered, flat colors, thick outline, plain white background".
- Tiling textures: "seamless tileable texture of X, top-down, even lighting". Check
  the edges match before using it.
- Concept art: describe the scene, mood and art style ("cartoon, bright, soft shading").

## Keeping an image

Move the ones you want out of `art/generated/` into a folder under `art/`
(for example `art/icons/sunflower.jpg`) and commit them. To use one in the
game, upload it in Studio (Asset Manager > Bulk Import) or Creator Hub. Upload
from a script would need the Open Cloud key to have `asset:read` and
`asset:write` permissions, which it does not have yet.
