load("schema.star", "schema")
load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("xpath.star", "xpath")

SESSIONS_PATH = "/status/sessions"
TRANSCODE_PATH = "/photo/:/transcode"

LIFETIME = 15
FPS = 20

def main(config):
  PLEX_URL = config.get("plex_url")
  PLEX_TOKEN = config.get("plex_token")
  USER_NAME = config.get("user_name")
  DEVICE_TYPE = config.get("device_type")

  if not PLEX_URL or not PLEX_TOKEN:
    return render.Root(
        child=render.Box(
            child=render.WrappedText("Plex Server not configured")
        )
    )

  def plex_get(path, **kwargs):
    return http.get(PLEX_URL + path, headers={"X-Plex-Token": PLEX_TOKEN}, **kwargs)

  def transcode(**params):
      id = params["url"]
      cached = cache.get(id)
      if cached:
          return cached

      response = plex_get(TRANSCODE_PATH, params=params)

      if response.status_code != 200:
          fail("Art not found", id)

      data = response.body()
      cache.set(id, data)

      return data

  response = plex_get(SESSIONS_PATH)
  if response.status_code != 200:
      fail("Plex API error", response.status_code)

  data = response.body()
  doc = xpath.loads(data)

  filters = [
    "@type='episode' or @type='movie'",
  ]
  if USER_NAME:
    filters.append("./User/@title='%s'" % USER_NAME)
  if DEVICE_TYPE:
    filters.append("./Player/@device='%s'" % DEVICE_TYPE)

  item = doc.query_node('//MediaContainer/Video[%s]' % " and ".join(filters))
  if not item:
    return []

  title = item.query("@title")
  year = item.query("@year")
  is_tv = item.query("@type") == "episode"
  state = item.query("./Player/@state")

  duration = int(item.query("@duration"))
  viewOffset = int(item.query("@viewOffset"))
  remaining = duration - viewOffset

  if is_tv:
    art_id = item.query("@grandparentThumb")
    show = item.query("@grandparentTitle")

    season = int(item.query("@parentIndex"))
    episode = int(item.query("@index"))
    episode_id = "S%s E%s" % (("0%d" % season if season < 10 else season), ("0%d" % episode if episode < 10 else episode))

    detail_text = "%s %s" % (show, episode_id)
  else:
    art_id = item.query("@thumb")
    detail_text = year

  text_width = 64-21-1

  return render.Root(
    child=render.Row(
      expanded=True,
      main_align="space_between",
      children=[
        render.Image(
          src=transcode(url=art_id, height="32", width="21"),
          height=32,
          width=21
        ),
        render.Padding(
          pad=(1,0,0,0),
          child=render.Column(
            expanded=True,
            main_align="space_between",
            children=[
              render.Marquee(width=text_width, child=render.Text(title, font="6x13")),
              render.Marquee(width=text_width, child=render.Text(detail_text)),
              render.Text("-%d min" % (remaining / 1000 / 60), font="CG-pixel-3x5-mono")
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
