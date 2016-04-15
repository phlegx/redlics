---
redis.log(redis.LOG_NOTICE, 'Redlics')

local func = cmsgpack.unpack(ARGV[1])
local keys = cmsgpack.unpack(ARGV[2])
local options = cmsgpack.unpack(ARGV[3])


local function operate(operator, keys)
  redis.call('BITOP', operator, options['dest'], unpack(keys))
  return options['dest']
end


local function AND(keys) return operate('AND', keys) end
local function OR(keys)  return operate('OR',  keys) end
local function XOR(keys) return operate('XOR', keys) end
local function NOT(keys) return operate('NOT', keys) end
local function MINUS(keys)
  local items = keys
  local src = table.remove(items, 1)
  local and_op = AND(keys)
  return XOR({ src, and_op })
end


local function operation(keys, options)
  if options['operator'] == 'MINUS' then
    return MINUS(keys)
  else
    return operate(options['operator'], keys)
  end
end


local function counts(keys, options)
  local result
  if options['bucketized'] then
    result = 0
    for i,v in ipairs(keys) do
      result = result + (redis.call('HGET', v[1], v[2]) or 0)
    end
  else
    result = redis.call('MGET', unpack(keys))
  end
  return result
end


local function plot_counts(keys, options)
  local plot = {}
  if options['bucketized'] then
    for i,v in ipairs(keys) do
      plot[v[1]..v[2]] = (redis.call('HGET', v[1], v[2]) or 0)
    end
  else
    local values = redis.call('MGET', unpack(keys))
    for i,v in ipairs(keys) do
      plot[v] = values[i]
    end
  end
  return cjson.encode(plot)
end


local function plot_tracks(keys, options)
  local plot = {}
  for i,v in ipairs(keys) do
    plot[v] = redis.call('bitcount', keys[i])
  end
  return cjson.encode(plot)
end


local exportFuncs = {
  operation = operation,
  counts = counts,
  plot_counts = plot_counts,
  plot_tracks = plot_tracks
}

return exportFuncs[func](keys, options)
