# It's a todo list... that's about it

<!--toc:start-->

- [It's a todo list... that's about it](#its-a-todo-list-thats-about-it)
  - [Usage](#usage)
  <!--toc:end-->

## Installation

Just go ahead and use any plugin manager you like, for example with LazyVim:

```lua
return {
  {
    "booka66/nvim_todo",
  },
}
```

You're gonna need Neorg for this to work (or at least look good), so make sure you have that installed. The plugin will write a ~/.todo.json file to store your todo items. The popup is made by parsing this file, so if you delete it, you'll lose your todo list. The popup is rendered using Neorg's stuff, so that's why you'll need it to look good.

## Usage

- <leader>tn - New todo item
- <leader>to - Open todo list
  - esc or q: close the popup
  - d: delete item (or category including all items)
  - enter: toggle item as done
  - e: edit item (or category)
