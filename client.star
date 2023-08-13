load("http.star", "http")
load("cache.star", "cache")
load("xpath.star", "xpath")

def client.config_valid(config):
  return config.get("plex_url") and config.get("plex_token")

def client.transcode(config, id, **params):
    params["url"] = id

    cached = cache.get(id)
    if cached:
        return cached

    response = client._get(config, "/photo/:/transcode", params=params)

    if response.status_code != 200:
        fail("Art not found", id)

    data = response.body()
    cache.set(id, data)

    return data

def client.now_playing(config):
  user_name = config.get("user_name")
  device_type = config.get("device_type")

  response = client._get(config, "/status/sessions")
  if response.status_code != 200:
      fail("Plex API error", response.status_code)

  data = response.body()
  doc = xpath.loads(data)

  filters = [
    "@type='episode' or @type='movie'",
  ]

  if user_name:
    filters.append("./User/@title='%s'" % user_name)
  if device_type:
    filters.append("./Player/@device='%s'" % device_type)

  query = '//MediaContainer/Video[(%s)]' % ") and (".join(filters)
  item = doc.query_node(query)
  if not item:
    return None

  title = item.query("@title")
  year = item.query("@year")
  tv = item.query("@type") == "episode"
  state = item.query("./Player/@state")

  duration = int(item.query("@duration"))
  view_offset = int(item.query("@viewOffset"))
  remaining = duration - view_offset

  metadata = {
    "title": title,
    "year": year,
    "tv": tv,
    "state": state,
    "duration": duration,
    "view_offset": view_offset,
    "remaining": remaining
  }

  if tv:
    season = int(item.query("@parentIndex"))
    episode = int(item.query("@index"))
    episode_id = "S%s E%s" % (("0%d" % season if season < 10 else season), ("0%d" % episode if episode < 10 else episode))

    metadata.update({
      "art_id": item.query("@grandparentThumb"),
      "show": item.query("@grandparentTitle"),
      "season": season,
      "episode": episode,
      "episode_id": episode_id
    })
  else:
    metadata["art_id"] = item.query("@thumb")

  return metadata

def client._get(config, path, **kwargs):
    return http.get(config.get("plex_url") + path, headers={"X-Plex-Token": config.get("plex_token")}, **kwargs)
