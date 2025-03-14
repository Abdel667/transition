-- Bicycle profile

api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
Handlers = require("lib/way_handlers")
find_access_tag = require("lib/access").find_access_tag
limit = require("lib/maxspeed").limit
Tags = require('lib/tags')
Measure = require("lib/measure")

function setup()
  local default_speed = 16
  local walking_speed = 5

  return {
    properties = {
      u_turn_penalty                = 20,
      traffic_light_penalty         = 15,
      -- Transition: we prefer cyclability as a baseline
      weight_name                   = 'cyclability',
      --weight_name                   = 'routability',
      process_call_tagless_node     = false,
      max_speed_for_map_matching    = 110/3.6, -- kmph -> m/s
      use_turn_restrictions         = false,
      continue_straight_at_waypoint = false,
      mode_change_penalty           = 30,
    },

    default_mode              = mode.cycling,
    default_speed             = default_speed,
    walking_speed             = walking_speed,
    oneway_handling           = true,
    turn_penalty              = 5,
    turn_bias                 = 1.4,
    use_public_transport      = false,

    allowed_start_modes = Set {
      mode.cycling,
      mode.pushing_bike
    },

    barrier_blacklist = Set {
      'yes',
      'wall',
      'fence'
    },

    access_tag_whitelist = Set {
      'yes',
      'routing:bicycle',
      'bicycle',
      'permissive',
      'designated',
      'discouraged' -- discouraged is for where it is dangerous, or bicycles should find another way, but permitted. See https://wiki.openstreetmap.org/wiki/Key:access#access-discouraged and https://wiki.openstreetmap.org/wiki/Key:bicycle
    },

    access_tag_blacklist = Set {
      'no',
      'private',
      'customers',
      'delivery',
      'agricultural',
      'forestry',
      'destination',
      'use_sidepath'
    },

    service_access_tag_blacklist = Set {
      --'private' -- default value in osrm default profile
    },

    restricted_access_tag_list = Set {
      'private',
      'delivery',
      'destination',
      'customers',
      'agricultural',
      'forestry'
    },

    restricted_highway_whitelist = Set {
      'trunk',
      'trunk_link',
      'primary',
      'primary_link',
      'secondary',
      'secondary_link',
      'tertiary',
      'tertiary_link',
      'residential',
      'living_street',
      'unclassified',
      'service',
      'footway',
      'bridleway',
      'track',
      'path',
      'cycleway',
      'pedestrian',
      'steps',
      'pier',
      'corridor',
    },

    -- tags disallow access to in combination with highway=service
    service_access_tag_blacklist = Set { },

    service_tag_forbidden = Set {
      'emergency_access'
    },

    service_penalties = {},

    construction_whitelist = Set {
      'no',
      'widening',
      'minor',
    },

    access_tags_hierarchy = Sequence {
      'routing:bicycle',
      'bicycle',
      'vehicle',
      'access'
    },

    restrictions = Set {
      'bicycle'
    },

    cycleway_tags = Set {
      'track',
      'lane',
      'share_busway',
      'sharrow',
      'shared',
      'shared_lane'
    },

    opposite_cycleway_tags = Set {
      'opposite',
      'opposite_lane',
      'opposite_track',
    },

    -- reduce the driving speed by 30% for unsafe roads
    -- only used for cyclability metric
    unsafe_highway_list = {
      trunk = 0.5,
      primary = 0.5,
      secondary = 0.65,
      tertiary = 0.8,
      residential = 0.9,
      trunk_link = 0.5,
      primary_link = 0.5,
      secondary_link = 0.65,
      tertiary_link = 0.8,
    },

    service_penalties = {
      alley             = 0.8,
    },

    bicycle_speeds = {
      cycleway = default_speed*1.08,
      trunk = default_speed*0.98,
      trunk_link = default_speed*0.98,
      primary = default_speed*0.98,
      primary_link = default_speed*0.98,
      secondary = default_speed*0.98,
      secondary_link = default_speed*0.98,
      tertiary = default_speed*0.98,
      tertiary_link = default_speed*0.98,
      residential = default_speed*1.0,
      unclassified = default_speed*0.98,
      living_street = default_speed*1.0,
      road = default_speed*0.98,
      bridleway = default_speed*0.98,
      service = default_speed*0.98,
      track = 12,
      path = 12
    },

    pedestrian_speeds = {
      footway = walking_speed,
      corridor = walking_speed,
      pedestrian = walking_speed,
      steps = 2
    },

    railway_speeds = {
      train = 10,
      railway = 10,
      subway = 10,
      light_rail = 10,
      monorail = 10,
      tram = 10
    },

    platform_speeds = {
      platform = walking_speed
    },

    amenity_speeds = {
      parking = 10,
      parking_entrance = 10
    },

    man_made_speeds = {
      pier = walking_speed
    },

    route_speeds = {
      ferry = 5
    },

    bridge_speeds = {
      movable = 5
    },

    surface_speeds = {
      asphalt = default_speed,
      ["cobblestone:flattened"] = 10,
      paving_stones = 12,
      compacted = 15,
      cobblestone = 6,
      unpaved = 15,
      fine_gravel = 15,
      gravel = 15,
      pebblestone = 6,
      ground = 6,
      dirt = 8,
      earth = 6,
      grass = 10,
      mud = 5,
      sand = 5,
      sett = 10
    },

    classes = Sequence {
        'ferry', 'tunnel'
    },

    -- Which classes should be excludable
    -- This increases memory usage so its disabled by default.
    excludable = Sequence {
--        Set {'ferry'}
    },

    tracktype_speeds = {
    },

    smoothness_speeds = {
    },

    avoid = Set {
      'impassable',
      --'construction'
    }
  }
end

function process_node(profile, node, result)
  -- parse access and barrier tags
  local highway = node:get_value_by_key("highway")
  local is_crossing = highway and highway == "crossing"

  local access = find_access_tag(node, profile.access_tags_hierarchy)
  if access and access ~= "" then
    -- access restrictions on crossing nodes are not relevant for
    -- the traffic on the road
    if profile.access_tag_blacklist[access] and not profile.restricted_access_tag_list[access] and not is_crossing then
      result.barrier = true
    end
  else
    local barrier = node:get_value_by_key("barrier")
    if barrier and "" ~= barrier then
      if profile.barrier_blacklist[barrier] then
        result.barrier = true
      end
    end
  end

  -- check if node is a traffic light
  local tag = node:get_value_by_key("highway")
  if tag and "traffic_signals" == tag then
    result.traffic_lights = true
  end
end

function handle_bicycle_tags(profile,way,result,data)
    -- initial routability check, filters out buildings, boundaries, etc
  data.route = way:get_value_by_key("route")
  data.man_made = way:get_value_by_key("man_made")
  data.railway = way:get_value_by_key("railway")
  data.amenity = way:get_value_by_key("amenity")
  data.public_transport = way:get_value_by_key("public_transport")
  data.bridge = way:get_value_by_key("bridge")

  if (not data.highway or data.highway == '') and
  (not data.route or data.route == '') and
  (not profile.use_public_transport or not data.railway or data.railway=='') and
  (not data.amenity or data.amenity=='') and
  (not data.man_made or data.man_made=='') and
  (not data.public_transport or data.public_transport=='') and
  (not data.bridge or data.bridge=='')
  then
    return false
  end

  -- access

  data.forward_access, data.backward_access =
    Tags.get_forward_backward_by_set(way,data,profile.access_tags_hierarchy)

  data.access = find_access_tag(way, profile.access_tags_hierarchy)
  if data.access and profile.access_tag_blacklist[data.access] and not profile.restricted_highway_whitelist[data.highway] then
    return false
  end
  if profile.restricted_highway_whitelist[data.highway] then
    if profile.restricted_access_tag_list[data.forward_access] then
        result.forward_restricted = true
    end

    if profile.restricted_access_tag_list[data.backward_access] then
        result.backward_restricted = true
    end
  
  end

  -- other tags
  data.junction = way:get_value_by_key("junction")
  data.maxspeed = Measure.get_max_speed(way:get_value_by_key ("maxspeed")) or 0
  data.maxspeed_forward = Measure.get_max_speed(way:get_value_by_key("maxspeed:forward")) or 0
  data.maxspeed_backward = Measure.get_max_speed(way:get_value_by_key("maxspeed:backward")) or 0
  data.barrier = way:get_value_by_key("barrier")
  data.oneway = way:get_value_by_key("oneway")
  data.oneway_bicycle = way:get_value_by_key("oneway:bicycle")
  data.cycleway = way:get_value_by_key("cycleway")
  data.cycleway_left = way:get_value_by_key("cycleway:left")
  data.cycleway_right = way:get_value_by_key("cycleway:right")
  data.duration = way:get_value_by_key("duration")
  data.service = way:get_value_by_key("service")
  data.foot = way:get_value_by_key("foot")
  data.foot_forward = way:get_value_by_key("foot:forward")
  data.foot_backward = way:get_value_by_key("foot:backward")
  data.bicycle = way:get_value_by_key("bicycle")
  data.bicycle_routing = way:get_value_by_key("routing:bicycle")

  speed_handler(profile,way,result,data)

  oneway_handler(profile,way,result,data)

  cycleway_handler(profile,way,result,data)

  bike_push_handler(profile,way,result,data)


  -- maxspeed
  limit( result, data.maxspeed, data.maxspeed_forward, data.maxspeed_backward )

  -- not routable if no speed assigned
  -- this avoid assertions in debug builds
  if result.forward_speed <= 0 and result.duration <= 0 then
    result.forward_mode = mode.inaccessible
  end
  if result.backward_speed <= 0 and result.duration <= 0 then
    result.backward_mode = mode.inaccessible
  end

  safety_handler(profile,way,result,data)
end



function speed_handler(profile,way,result,data)

  data.way_type_allows_pushing = false

  -- speed
  local bridge_speed = profile.bridge_speeds[data.bridge]
  if (bridge_speed and bridge_speed > 0) then
    data.highway = data.bridge
    if data.duration and durationIsValid(data.duration) then
      result.duration = math.max( parseDuration(data.duration), 1 )
    end
    result.forward_speed = bridge_speed
    result.backward_speed = bridge_speed
    data.way_type_allows_pushing = true
  elseif profile.route_speeds[data.route] then
    -- ferries (doesn't cover routes tagged using relations)
    result.forward_mode = mode.ferry
    result.backward_mode = mode.ferry
    if data.duration and durationIsValid(data.duration) then
      result.duration = math.max( 1, parseDuration(data.duration) )
    else
       result.forward_speed = profile.route_speeds[data.route]
       result.backward_speed = profile.route_speeds[data.route]
    end
  -- railway platforms (old tagging scheme)
  elseif data.railway and profile.platform_speeds[data.railway] then
    result.forward_speed = profile.platform_speeds[data.railway]
    result.backward_speed = profile.platform_speeds[data.railway]
    data.way_type_allows_pushing = true
  -- public_transport platforms (new tagging platform)
  elseif data.public_transport and profile.platform_speeds[data.public_transport] then
    result.forward_speed = profile.platform_speeds[data.public_transport]
    result.backward_speed = profile.platform_speeds[data.public_transport]
    data.way_type_allows_pushing = true
  -- railways
  elseif profile.use_public_transport and data.railway and profile.railway_speeds[data.railway] and profile.access_tag_whitelist[data.access] then
    result.forward_mode = mode.train
    result.backward_mode = mode.train
    result.forward_speed = profile.railway_speeds[data.railway]
    result.backward_speed = profile.railway_speeds[data.railway]
  elseif data.amenity and profile.amenity_speeds[data.amenity] then
    -- parking areas
    result.forward_speed = profile.amenity_speeds[data.amenity]
    result.backward_speed = profile.amenity_speeds[data.amenity]
    data.way_type_allows_pushing = true
  elseif profile.bicycle_speeds[data.highway] then
    -- regular ways
    result.forward_speed = profile.bicycle_speeds[data.highway]
    result.backward_speed = profile.bicycle_speeds[data.highway]
    data.way_type_allows_pushing = true
  elseif data.access and profile.access_tag_whitelist[data.access]  then
    -- unknown way, but valid access tag
    result.forward_speed = profile.default_speed
    result.backward_speed = profile.default_speed
    data.way_type_allows_pushing = true
  end
end

function oneway_handler(profile,way,result,data)
  -- oneway
  data.implied_oneway = data.junction == "roundabout" or data.junction == "circular" or data.highway == "motorway"
  data.reverse = false

  if data.oneway_bicycle == "yes" or data.oneway_bicycle == "1" or data.oneway_bicycle == "true" then
    result.backward_mode = mode.inaccessible
  elseif data.oneway_bicycle == "no" or data.oneway_bicycle == "0" or data.oneway_bicycle == "false" then
   -- prevent other cases
  elseif data.oneway_bicycle == "-1" then
    result.forward_mode = mode.inaccessible
    data.reverse = true
  elseif data.oneway == "yes" or data.oneway == "1" or data.oneway == "true" then
    result.backward_mode = mode.inaccessible
  elseif data.oneway == "no" or data.oneway == "0" or data.oneway == "false" then
    -- prevent other cases
  elseif data.oneway == "-1" then
    result.forward_mode = mode.inaccessible
    data.reverse = true
  elseif data.implied_oneway then
    result.backward_mode = mode.inaccessible
  end
end

function cycleway_handler(profile,way,result,data)
  -- cycleway
  data.has_cycleway_forward = false
  data.has_cycleway_backward = false
  data.is_twoway = result.forward_mode ~= mode.inaccessible and result.backward_mode ~= mode.inaccessible and not data.implied_oneway

  -- cycleways on normal roads
  if data.is_twoway then
    if data.cycleway and profile.cycleway_tags[data.cycleway] then
      data.has_cycleway_backward = true
      data.has_cycleway_forward = true
    end
    if (data.cycleway_right and profile.cycleway_tags[data.cycleway_right]) or (data.cycleway_left and profile.opposite_cycleway_tags[data.cycleway_left]) then
      data.has_cycleway_forward = true
    end
    if (data.cycleway_left and profile.cycleway_tags[data.cycleway_left]) or (data.cycleway_right and profile.opposite_cycleway_tags[data.cycleway_right]) then
      data.has_cycleway_backward = true
    end
  else
    local has_twoway_cycleway = (data.cycleway and profile.opposite_cycleway_tags[data.cycleway]) or (data.cycleway_right and profile.opposite_cycleway_tags[data.cycleway_right]) or (data.cycleway_left and profile.opposite_cycleway_tags[data.cycleway_left])
    local has_opposite_cycleway = (data.cycleway_left and profile.opposite_cycleway_tags[data.cycleway_left]) or (data.cycleway_right and profile.opposite_cycleway_tags[data.cycleway_right])
    local has_oneway_cycleway = (data.cycleway and profile.cycleway_tags[data.cycleway]) or (data.cycleway_right and profile.cycleway_tags[data.cycleway_right]) or (data.cycleway_left and profile.cycleway_tags[data.cycleway_left])

    -- set cycleway even though it is an one-way if opposite is tagged
    if has_twoway_cycleway then
      data.has_cycleway_backward = true
      data.has_cycleway_forward = true
    elseif has_opposite_cycleway then
      if not data.reverse then
        data.has_cycleway_backward = true
      else
        data.has_cycleway_forward = true
      end
    elseif has_oneway_cycleway then
      if not data.reverse then
        data.has_cycleway_forward = true
      else
        data.has_cycleway_backward = true
      end

    end
  end

  if data.has_cycleway_backward then
    result.backward_mode = mode.cycling
    result.backward_speed = profile.bicycle_speeds["cycleway"]
  end

  if data.has_cycleway_forward then
    result.forward_mode = mode.cycling
    result.forward_speed = profile.bicycle_speeds["cycleway"]
  end
end

function bike_push_handler(profile,way,result,data)
  -- pushing bikes - if no other mode found
  if result.forward_mode == mode.inaccessible or result.backward_mode == mode.inaccessible or
    result.forward_speed == -1 or result.backward_speed == -1 then
    if data.foot ~= 'no' then
      local push_forward_speed = nil
      local push_backward_speed = nil

      if profile.pedestrian_speeds[data.highway] then
        push_forward_speed = profile.pedestrian_speeds[data.highway]
        push_backward_speed = profile.pedestrian_speeds[data.highway]
      elseif data.man_made and profile.man_made_speeds[data.man_made] then
        push_forward_speed = profile.man_made_speeds[data.man_made]
        push_backward_speed = profile.man_made_speeds[data.man_made]
      else
        if data.foot == 'yes' then
          push_forward_speed = profile.walking_speed
          if not data.implied_oneway then
            push_backward_speed = profile.walking_speed
          end
        elseif data.foot_forward == 'yes' then
          push_forward_speed = profile.walking_speed
        elseif data.foot_backward == 'yes' then
          push_backward_speed = profile.walking_speed
        elseif data.way_type_allows_pushing then
          push_forward_speed = profile.walking_speed
          if not data.implied_oneway then
            push_backward_speed = profile.walking_speed
          end
        end
      end

      if push_forward_speed and (result.forward_mode == mode.inaccessible or result.forward_speed == -1) then
        result.forward_mode = mode.pushing_bike
        result.forward_speed = push_forward_speed
      end
      if push_backward_speed and (result.backward_mode == mode.inaccessible or result.backward_speed == -1)then
        result.backward_mode = mode.pushing_bike
        result.backward_speed = push_backward_speed
      end

    end

  end

  -- dismount
  if data.bicycle == "dismount" then
    result.forward_mode = mode.pushing_bike
    result.backward_mode = mode.pushing_bike
    result.forward_speed = profile.walking_speed
    result.backward_speed = profile.walking_speed
  end

  if data.bicycle_routing == "use_sidepath" then
    result.forward_mode = mode.inaccessible
    result.backward_mode = mode.inaccessible
  end
end

function safety_handler(profile,way,result,data)
  -- convert duration into cyclability
  if profile.properties.weight_name == 'cyclability' then
    local safety_penalty = profile.unsafe_highway_list[data.highway] or 1.
    local is_unsafe = safety_penalty < 1

    -- primaries that are one ways are probably huge primaries where the lanes need to be separated
    if is_unsafe and data.highway == 'primary' and not data.is_twoway then
      safety_penalty = safety_penalty * 0.5
    end
    if is_unsafe and data.highway == 'secondary' and not data.is_twoway then
      safety_penalty = safety_penalty * 0.6
    end

    local forward_is_unsafe = is_unsafe and not data.has_cycleway_forward
    local backward_is_unsafe = is_unsafe and not data.has_cycleway_backward
    local is_undesireable = data.highway == "service" and profile.service_penalties[data.service]
    local forward_penalty = 1.
    local backward_penalty = 1.
    if forward_is_unsafe then
      forward_penalty = math.min(forward_penalty, safety_penalty)
    end
    if backward_is_unsafe then
       backward_penalty = math.min(backward_penalty, safety_penalty)
    end

    if is_undesireable then
       forward_penalty = math.min(forward_penalty, profile.service_penalties[data.service])
       backward_penalty = math.min(backward_penalty, profile.service_penalties[data.service])
    end

    -- Transition: Add penalty for bicycle=discouraged tag
    -- See the link above about the discouraged tag
    local bicycle_tag = way:get_value_by_key("bicycle")
    if bicycle_tag == "discouraged" then
       forward_penalty = forward_penalty * 0.5
       backward_penalty = backward_penalty * 0.5
    end

    if result.forward_speed > 0 then
      -- convert from km/h to m/s
      result.forward_rate = result.forward_speed / 3.6 * forward_penalty
    end
    if result.backward_speed > 0 then
      -- convert from km/h to m/s
      result.backward_rate = result.backward_speed / 3.6 * backward_penalty
    end
    if result.duration > 0 then
      result.weight = result.duration / forward_penalty
    end

    if data.highway == "bicycle" then
      safety_bonus = safety_bonus + 0.2
      if result.forward_speed > 0 then
        -- convert from km/h to m/s
        result.forward_rate = result.forward_speed / 3.6 * safety_bonus
      end
      if result.backward_speed > 0 then
        -- convert from km/h to m/s
        result.backward_rate = result.backward_speed / 3.6 * safety_bonus
      end
      if result.duration > 0 then
        result.weight = result.duration / safety_bonus
      end
    end
  end
end


function process_way(profile, way, result)
  -- the initial filtering of ways based on presence of tags
  -- affects processing times significantly, because all ways
  -- have to be checked.
  -- to increase performance, prefetching and initial tag check
  -- is done directly instead of via a handler.

  -- in general we should try to abort as soon as
  -- possible if the way is not routable, to avoid doing
  -- unnecessary work. this implies we should check things that
  -- commonly forbids access early, and handle edge cases later.

  -- data table for storing intermediate values during processing

  local data = {
    -- prefetch tags
    highway = way:get_value_by_key('highway'),

    route = nil,
    man_made = nil,
    railway = nil,
    amenity = nil,
    public_transport = nil,
    bridge = nil,

    access = nil,

    junction = nil,
    maxspeed = nil,
    maxspeed_forward = nil,
    maxspeed_backward = nil,
    barrier = nil,
    oneway = nil,
    oneway_bicycle = nil,
    cycleway = nil,
    cycleway_left = nil,
    cycleway_right = nil,
    duration = nil,
    service = nil,
    foot = nil,
    foot_forward = nil,
    foot_backward = nil,
    bicycle = nil,

    way_type_allows_pushing = false,
    has_cycleway_forward = false,
    has_cycleway_backward = false,
    is_twoway = true,
    reverse = false,
    implied_oneway = false



  }

  local handlers = Sequence {
    -- set the default mode for this profile. if can be changed later
    -- in case it turns we're e.g. on a ferry
    WayHandlers.default_mode,

    -- check various tags that could indicate that the way is not
    -- routable. this includes things like status=impassable,
    -- toll=yes and oneway=reversible
    WayHandlers.blocked_ways,
    WayHandlers.avoid_ways,

    -- our main handler
    handle_bicycle_tags,

    WayHandlers.access,

    -- compute speed taking into account way type, maxspeed tags, etc.
    WayHandlers.surface,

    -- handle turn lanes and road classification, used for guidance
    WayHandlers.classification,

    -- handle allowed start/end modes
    WayHandlers.startpoint,

    -- handle roundabouts
    WayHandlers.roundabouts,
    WayHandlers.penalties,

    -- set name, ref and pronunciation
    WayHandlers.names,

    -- set classes
    WayHandlers.classes,

    -- set weight properties of the way
    WayHandlers.weights
  }

  WayHandlers.run(profile, way, result, data, handlers)
end

function process_turn(profile, turn)

  turn.duration = profile.turn_penalty
  -- compute turn penalty as angle^2, with a left/right bias
  local normalized_angle = turn.angle / 90.0
  if normalized_angle >= 0.0 then
    turn.duration = normalized_angle * normalized_angle * profile.turn_penalty / profile.turn_bias
  else
    turn.duration = normalized_angle * normalized_angle * profile.turn_penalty * profile.turn_bias
  end

  if turn.is_u_turn then
    turn.duration = turn.duration + profile.properties.u_turn_penalty
  end

  if turn.has_traffic_light then
     turn.duration = turn.duration + profile.properties.traffic_light_penalty
  end
  if profile.properties.weight_name == 'routability' then
    turn.weight = turn.duration
  end
  if turn.source_mode == mode.cycling and turn.target_mode ~= mode.cycling then
    turn.weight = turn.weight + profile.properties.mode_change_penalty
  end
  if profile.properties.weight_name == 'routability' then--
    -- penalize turns from non-local access only segments onto local access only tags
    if not turn.source_restricted and turn.target_restricted then
        turn.weight = turn.weight + 3000
    end
  end
end

return {
  setup = setup,
  process_way = process_way,
  process_node = process_node,
  process_turn = process_turn
}
