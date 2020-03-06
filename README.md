# unimenu

Universal menu library for CS2D. Unimenu 2.0 is a significant upgrade compared to 1.0. It is more flexible, more powerful and more robust, while also being generally cleaner.

## Function reference

| Function | Description |
| - | - |
| `open(id: number, spec: string or MenuSpec[, page: number])` | Opens a menu to the specified player according to the given spec. If `spec` is a string, attempts to find a globally registered spec. If `page` is unspecified, it is set to `1`. This clears a player's forward history and pushes their current menu, if one is open, to the back history stack. |
| `historyBack(id: number)` | Goes back in history. Opens the historical menu and pushes the current menu to the forward history stack. |
| `historyForward(id: number)` | Goes forward in history. Opens the historical menu and pushes the current menu to the back history stack. |
| `switchPage(id: number, page: number)` | Switches the player's current page to the specified number, clamped between `1` and the last page. Does not alter history in any way. |
| `getCurrentPage(id: number)` | Gets the currently open page for the player. |
| `register(name: string, spec: MenuSpec)` | Globally registers a spec under the given name. |
| `setDefault(name: string, value: any)` | Sets the value for the global default with the given name. |
| `getDefault(name: string)` | Gets the global default for the given name. |
| `getSpec(name: string)` | Gets the globally registered spec under the given name. |
| `getCurrent(id: number)` | Gets information about the currently open menu for the player. |
| `getBackHistory(id: number)` | Gets the back history stack for the player. |
| `getForwardHistory(id: number)` | Gets the forward history stack for the player. |

## Globals reference

Unimenu supports the following globals:

| Key | Value type | Default | Description |
| - | - | - | - |
| `BACK` | `{string, string}` | `{"< Back", ""}` | Default caption and description for the previous page button. |
| `NEXT` | `{string, string}` | `{"Next >", ""}` | Default caption and description for the next page button. |
| `TITLE_FORMATTER` | `function(title: string, page: number)` | Outputs `${title} (Page ${page})` | Default formatter function for string titles. |

## Spec reference

A menu spec may have the following keys:

| Key | Value types | Required | Default | Description |
| - | - | - | - | - |
| `title` | `string` or `function(page: number)` | **YES** | | The title that will be used for this menu, or a formatter function that returns the title. If this is a simple string, it will be used as the `title` argument in the `TITLE_FORMATTER` global. If this is a formatter function, it bypasses `TITLE_FORMATTER` completely. |
| `items` | `Item[]` | **YES** | | Items to display in the menu. |
| `fixedItems` | `Item[]` |  |  | Fixed items that should appear on every page. An item's key in this table corresponds to the position it will appear at in the menu. These may overwrite Back and Next. |
| `backText` | `{string, string}` |  | Global `BACK` | Caption and description for the back button. |
| `nextText` | `{string, string}` |  | Global `NEXT` | Caption and description for the next button. |
| `invisible` | `boolean` |  | `false` | Whether the menu should appear invisible (`@i`). Takes precedence over the `big` setting. |
| `big` | `boolean` |  | `false` | Whether the menu should appear large (`@b`). |
| `perPage` | `number` |  | `7` | How many items should appear on a page. There are guaranteed to be at most this many items, however fewer may appear, depending on how many fixed items there are. |
| `loop` | `boolean` |  | `false` | If `true`, pressing Back on the first page will land you on the final page of the menu, and pressing Next on the last page will land you on the first. |
| `onPrevPage` | `function(id: number, page: number)` |  |  | Runs whenever a player moves to the previous page. |
| `onNextPage` | `function(id: number, page: number)` |  |  | Runs whenever a player moves to the next page. |
| `onCancel` | `function(id: number)` |  |  | Runs whenever a player presses Cancel, 0, Esc or the X button. |

An item spec may have the following keys:

| Key | Value types | Required | Description |
| - | - | - | - |
| `caption` | `string` |  | Main button text |
| `desc` | `string` |  | Side button text |
| `func` | `function(id: number)` |  | Function to call on button press |
| `disabled` | `boolean` |  | Whether the button should appear disabled |

The above keys may also appear as simple numeric keys, in the order specified above.

## Examples

```lua
local unimenu = require("unimenu")

local spec2 = {
    title = "Submenu",
    items = {
        {"Sub item", "Sub desc", function(id) msg2(id, "Sub") end}
    },
    fixedItems = {
        [7] = {"<< Return", "", function(id) unimenu.historyBack(id) end}
    },
}

local spec = {
    title = function(page) return "[" .. page .. "] Test menu" end,
    items = {},
    perPage = 3,
    fixedItems = {
        [1] = {"Open submenu", "", function(id) unimenu.open(id, spec2) end},
    },
    loop = true,
}

for i = 1, 21 do
    table.insert(spec.items, {"Test item " .. i, "Test desc " .. i, function(id) msg2(id, "Hello " .. i) end})
end

addhook("serveraction", "__unimenutest")
function __unimenutest(id, action)
    if (action == 1) then
        unimenu.open(id, spec)
    end
end
```
