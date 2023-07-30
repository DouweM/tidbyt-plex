load("schema.star", "schema")
load("render.star", "render")
load("pixlib/const.star", "const")
load("pixlib/file.star", "file")
load("./client.star", "client")

PLEX_LOGO_URL = "https://www.plex.tv/wp-content/themes/plex/assets/img/favicons/plex-76.png"

ART_HEIGHT = const.HEIGHT
ART_WIDTH = 21
TEXT_WIDTH = const.WIDTH - ART_WIDTH - 1

def main(config):
  if not client.config_valid(config):
    return render.Root(
        child=render.Box(
            child=render.WrappedText("Plex Server not configured")
        )
    )

  item = client.now_playing(config)
  if not item:
    return []

  art_id = item.get("art_id")
  art = (
    client.transcode(config, art_id, height=str(ART_HEIGHT), width=str(ART_WIDTH))
    if art_id
    else file.read("placeholder.png")
  )

  if item.get("tv", False):
    detail_text = " ".join([item.get("show"), item.get("episode_id")])
  else:
    detail_text = item.get("year")

  return render.Root(
    child=render.Row(
      expanded=True,
      main_align="space_between",
      children=[
        render.Image(src=art, height=ART_HEIGHT, width=ART_WIDTH),
        render.Padding(
          pad=(1,0,0,0),
          child=render.Column(
            expanded=True,
            main_align="space_between",
            children=[
              render.Marquee(width=TEXT_WIDTH, child=render.Text(item.get("title"), font="6x13")),
              render.Marquee(width=TEXT_WIDTH, child=render.Text(detail_text)),
              render.Text("-%d min" % (item.get("remaining") / 1000 / 60), font="CG-pixel-3x5-mono")
            ]
          )
        )
      ]
    )
  )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "plex_url",
                name = "Plex Server URL",
                desc = "If HTTPS, certificate must be valid. Example: 'http://my-nas:32400'",
                icon = "link"
            ),
            schema.Text(
                id = "plex_token",
                name = "Plex API Token",
                desc = "See https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/",
                icon = "key",
            ),
            schema.Text(
                id = "user_name",
                name = "Filter: User Name",
                desc = "Leave blank to consider sessions from all users",
                icon = "user",
            ),
            schema.Text(
                id = "device_type",
                name = "Filter: Device Type",
                desc = "Leave blank to consider sessions from all types of devices. Example: 'Apple TV'",
                icon = "tv"
            ),
        ],
    )
