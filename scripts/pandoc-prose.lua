-- Pandoc filter used only by the asynchronous statusline word counter.
-- It removes source constructs that are not prose written for rendering.

local visible_metadata = {
  "title",
  "subtitle",
  "author",
  "date",
  "abstract",
}

function Meta(metadata)
  local kept = {}
  for _, key in ipairs(visible_metadata) do
    if metadata[key] ~= nil then
      kept[key] = metadata[key]
    end
  end
  return kept
end

function Code()
  return {}
end

function CodeBlock()
  return {}
end

function Math()
  return {}
end

function RawInline()
  return {}
end

function RawBlock()
  return {}
end

function Image()
  return {}
end

function Figure(element)
  local visible = pandoc.List()
  if element.content then
    visible:extend(element.content)
  end
  local caption = element.caption
  if caption and caption.long and #caption.long > 0 then
    visible:extend(caption.long)
    return visible
  end
  if caption and caption.short and #caption.short > 0 then
    visible:insert(pandoc.Plain(caption.short))
  end
  return visible
end

function Cite(element)
  local visible = pandoc.List()
  for _, citation in ipairs(element.citations) do
    visible:extend(citation.prefix)
    visible:extend(citation.suffix)
  end
  return visible
end

function Pandoc(document)
  local kept = pandoc.List()
  local index = 1
  while index <= #document.blocks do
    local block = document.blocks[index]
    local next_block = document.blocks[index + 1]
    local generated_references = block.t == "Header"
      and next_block
      and next_block.t == "Div"
      and next_block.identifier == "refs"
    if generated_references then
      index = index + 2
    elseif block.t == "Div" and block.identifier == "refs" then
      index = index + 1
    else
      kept:insert(block)
      index = index + 1
    end
  end
  document.blocks = kept
  return document
end
