local M = {}

function M.set_keymaps()
	local opts = { noremap = true, silent = true }

	-- Make a new todo item
	vim.api.nvim_set_keymap(
		"n",
		"<leader>tn",
		":lua require('todo').AddTodoItem()<CR>",
		{ noremap = true, silent = true, desc = "[nvim-todo] Create Todo Item" }
	)

	-- Toggle Todo list
	vim.api.nvim_set_keymap(
		"n",
		"<leader>to",
		":lua require('todo').ShowTodo()<CR>",
		{ noremap = true, silent = true, desc = "[nvim-todo] Toggle Todo" }
	)
end

function M.setup(opts)
	opts = opts or {}
	M.set_keymaps()
end

function M.ShowTodo()
	local file_path = os.getenv("HOME") .. "/.todo.json"
	local file = io.open(file_path, "r")
	if not file then
		vim.notify("Failed to open the JSON file: " .. file_path, "error", { title = "Todo" })
		return
	end

	local content = file:read("*all")
	file:close()

	local todo_list = {}
	if content ~= "" then
		todo_list = vim.fn.json_decode(content)
	end

	local categories = {}
	for _, todo in ipairs(todo_list) do
		if not categories[todo.category] then
			categories[todo.category] = {}
		end
		table.insert(categories[todo.category], todo)
	end

	-- Sort the categories alphabetically
	local sorted_categories = {}
	for category, _ in pairs(categories) do
		table.insert(sorted_categories, category)
	end
	table.sort(sorted_categories)

	local neorg_content = "*Todo List*\n"
	for _, category in ipairs(sorted_categories) do
		neorg_content = neorg_content .. "* " .. category .. "\n"

		-- Sort the todo items within each category chronologically
		table.sort(categories[category], function(a, b)
			return a.created < b.created
		end)

		for _, todo in ipairs(categories[category]) do
			local state_mark = todo.state == "important" and "!" or (todo.state == "pending" and "-" or " ")
			local completed_mark = todo.completed and "x" or state_mark
			neorg_content = neorg_content .. "- (" .. completed_mark .. ") " .. todo.item .. "\n"
		end
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(neorg_content, "\n"))
	vim.api.nvim_buf_set_option(buf, "filetype", "norg")

	local width = 120
	local height = 50
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Set up key mapping to edit an item or category
	vim.api.nvim_buf_set_keymap(buf, "n", "e", ":lua EditItem()<CR>", { noremap = true, silent = true })
	-- Set up key mapping to mark an item as important
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"i",
		":lua require('todo').MarkImportant()<CR>",
		{ noremap = true, silent = true }
	)
	-- Set up key mapping to mark an item as pending
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"p",
		":lua require('todo').MarkPending()<CR>",
		{ noremap = true, silent = true }
	)
	-- Set up key mapping to toggle completed status
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":lua ToggleCompleted()<CR>", { noremap = true, silent = true })
	-- Set up key mapping to delete an item or category
	vim.api.nvim_buf_set_keymap(buf, "n", "d", ":lua DeleteItem()<CR>", { noremap = true, silent = true })
	-- Set up key mapping to close the window
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<Esc>",
		":lua vim.api.nvim_win_close(0, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"q",
		":lua vim.api.nvim_win_close(0, true)<CR>",
		{ noremap = true, silent = true }
	)
end

function M.EditItem()
	local buf = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_get_current_line()

	local category = string.match(line, "^%*%s(.+)$")
	local item = string.match(line, "^%-%s%b()%s(.+)$")

	if category then
		vim.ui.input({
			prompt = "Edit category: ",
			default = category,
		}, function(new_category)
			if new_category then
				local file_path = os.getenv("HOME") .. "/.todo.json"
				local file = io.open(file_path, "r")
				local todo_list = {}
				if file then
					local content = file:read("*all")
					file:close()
					if content ~= "" then
						todo_list = vim.fn.json_decode(content)
					end
				end

				for _, todo in ipairs(todo_list) do
					if todo.category == category then
						todo.category = new_category
					end
				end

				local file = io.open(file_path, "w")
				if file then
					file:write(vim.fn.json_encode(todo_list))
					file:close()

					vim.api.nvim_buf_set_lines(
						buf,
						vim.fn.line(".") - 1,
						vim.fn.line("."),
						false,
						{ "* " .. new_category }
					)
				else
					vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
				end
			end
		end)
	elseif item then
		vim.ui.input({
			prompt = "Edit item: ",
			default = item,
		}, function(new_item)
			if new_item then
				local file_path = os.getenv("HOME") .. "/.todo.json"
				local file = io.open(file_path, "r")
				local todo_list = {}
				if file then
					local content = file:read("*all")
					file:close()
					if content ~= "" then
						todo_list = vim.fn.json_decode(content)
					end
				end

				local updated_todo = nil
				for _, todo in ipairs(todo_list) do
					if todo.item == item then
						todo.item = new_item
						updated_todo = todo
						break
					end
				end

				local file = io.open(file_path, "w")
				if file then
					file:write(vim.fn.json_encode(todo_list))
					file:close()

					if updated_todo then
						local completed_mark = updated_todo.completed and "x" or " "
						vim.api.nvim_buf_set_lines(
							buf,
							vim.fn.line(".") - 1,
							vim.fn.line("."),
							false,
							{ "- (" .. completed_mark .. ") " .. new_item }
						)
					end
				else
					vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
				end
			end
		end)
	end
end

function M.DeleteItem()
	local buf = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_get_current_line()

	local category = string.match(line, "^%*%s(.+)$")
	local item = string.match(line, "^%-%s%b()%s(.+)$")

	if category then
		vim.ui.input({
			prompt = "Are you sure you want to delete all items in the category '" .. category .. "'? (y/n): ",
		}, function(confirm)
			if confirm == "y" then
				local file_path = os.getenv("HOME") .. "/.todo.json"
				local file = io.open(file_path, "r")
				local todo_list = {}
				if file then
					local content = file:read("*all")
					file:close()
					if content ~= "" then
						todo_list = vim.fn.json_decode(content)
					end
				end

				local updated_todo_list = {}
				for _, todo in ipairs(todo_list) do
					if todo.category ~= category then
						table.insert(updated_todo_list, todo)
					end
				end

				local file = io.open(file_path, "w")
				if file then
					file:write(vim.fn.json_encode(updated_todo_list))
					file:close()

					-- Update the current buffer directly
					local start_line = vim.fn.line(".")
					local end_line = start_line
					while vim.fn.getline(end_line + 1):match("^%-%s") do
						end_line = end_line + 1
					end
					vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, false, {})
				else
					vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
				end
			end
		end)
	elseif item then
		vim.ui.input({
			prompt = "Are you sure you want to delete the item? (y/n): ",
		}, function(confirm)
			if confirm == "y" then
				local file_path = os.getenv("HOME") .. "/.todo.json"
				local file = io.open(file_path, "r")
				local todo_list = {}
				if file then
					local content = file:read("*all")
					file:close()
					if content ~= "" then
						todo_list = vim.fn.json_decode(content)
					end
				end

				local updated_todo_list = {}
				for _, todo in ipairs(todo_list) do
					if todo.item ~= item then
						table.insert(updated_todo_list, todo)
					end
				end

				local file = io.open(file_path, "w")
				if file then
					file:write(vim.fn.json_encode(updated_todo_list))
					file:close()

					-- Update the current buffer directly
					vim.api.nvim_buf_set_lines(buf, vim.fn.line(".") - 1, vim.fn.line("."), false, {})
				else
					vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
				end
			end
		end)
	end
end

function M.ToggleCompleted()
	local buf = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_get_current_line()

	local item = string.match(line, "^%-%s%b()%s(.+)$")
	if item then
		local file_path = os.getenv("HOME") .. "/.todo.json"
		local file = io.open(file_path, "r")
		local todo_list = {}
		if file then
			local content = file:read("*all")
			file:close()
			if content ~= "" then
				todo_list = vim.fn.json_decode(content)
			end
		end

		local updated_todo = nil
		for i, todo in ipairs(todo_list) do
			if todo.item == item then
				todo_list[i].completed = not todo_list[i].completed
				updated_todo = todo_list[i]
				break
			end
		end

		local file = io.open(file_path, "w")
		if file then
			file:write(vim.fn.json_encode(todo_list))
			file:close()

			-- Update the current buffer instead of calling ShowTodo()
			if updated_todo then
				local state_mark = updated_todo.state == "important" and "!"
					or (updated_todo.state == "pending" and "-" or " ")
				local completed_mark = updated_todo.completed and "x" or state_mark
				vim.api.nvim_buf_set_lines(
					buf,
					vim.fn.line(".") - 1,
					vim.fn.line("."),
					false,
					{ "- (" .. completed_mark .. ") " .. item }
				)
			end
		else
			vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
		end
	end
end

function M.MarkImportant()
	local buf = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_get_current_line()

	local item = string.match(line, "^%-%s%b()%s(.+)$")
	if item then
		local file_path = os.getenv("HOME") .. "/.todo.json"
		local file = io.open(file_path, "r")
		local todo_list = {}
		if file then
			local content = file:read("*all")
			file:close()
			if content ~= "" then
				todo_list = vim.fn.json_decode(content)
			end
		end

		local updated_todo = nil
		for i, todo in ipairs(todo_list) do
			if todo.item == item then
				todo_list[i].state = "important"
				updated_todo = todo_list[i]
				break
			end
		end

		local file = io.open(file_path, "w")
		if file then
			file:write(vim.fn.json_encode(todo_list))
			file:close()

			if updated_todo then
				local completed_mark = updated_todo.completed and "x" or "!"
				vim.api.nvim_buf_set_lines(
					buf,
					vim.fn.line(".") - 1,
					vim.fn.line("."),
					false,
					{ "- (" .. completed_mark .. ") " .. item }
				)
			end
		else
			vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
		end
	end
end

function M.MarkPending()
	local buf = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_get_current_line()

	local item = string.match(line, "^%-%s%b()%s(.+)$")
	if item then
		local file_path = os.getenv("HOME") .. "/.todo.json"
		local file = io.open(file_path, "r")
		local todo_list = {}
		if file then
			local content = file:read("*all")
			file:close()
			if content ~= "" then
				todo_list = vim.fn.json_decode(content)
			end
		end

		local updated_todo = nil
		for i, todo in ipairs(todo_list) do
			if todo.item == item then
				todo_list[i].state = "pending"
				updated_todo = todo_list[i]
				break
			end
		end

		local file = io.open(file_path, "w")
		if file then
			file:write(vim.fn.json_encode(todo_list))
			file:close()

			if updated_todo then
				local completed_mark = updated_todo.completed and "x" or "-"
				vim.api.nvim_buf_set_lines(
					buf,
					vim.fn.line(".") - 1,
					vim.fn.line("."),
					false,
					{ "- (" .. completed_mark .. ") " .. item }
				)
			end
		else
			vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
		end
	end
end

function M.AddTodoItem()
	local file_path = os.getenv("HOME") .. "/.todo.json"
	local file = io.open(file_path, "r")
	local todo_list = {}

	if file then
		local content = file:read("*all")
		file:close()
		if content ~= "" then
			todo_list = vim.fn.json_decode(content)
		end
	end

	local categories = {}
	for _, todo in ipairs(todo_list) do
		if not categories[todo.category] then
			categories[todo.category] = { count = 0, key = "" }
		end
		categories[todo.category].count = categories[todo.category].count + 1
	end

	if next(categories) == nil then
		-- No existing categories, jump straight into creating a new one
		vim.ui.input({
			prompt = "Enter a new category: ",
		}, function(category)
			if category then
				AddTodoItemWithCategory(category)
			else
				print("No category entered.")
			end
		end)
	else
		-- Create a selection screen for existing categories
		local category_list = {}
		local keys = {}
		local max_count = 0
		local max_category = nil

		for category, data in pairs(categories) do
			if data.count > max_count then
				max_count = data.count
				max_category = category
			end
			table.insert(category_list, category)
		end

		-- Assign the least number of repeated letters to the category with the most items
		categories[max_category].key = max_category:sub(1, 1):lower()
		keys[categories[max_category].key] = max_category

		-- Generate unique keys for the remaining categories
		for _, category in ipairs(category_list) do
			if category ~= max_category then
				local key = category:sub(1, 1):lower()
				local counter = 1
				while keys[key] do
					key = string.rep(category:sub(1, 1):lower(), counter + 1)
					counter = counter + 1
				end
				categories[category].key = key
				keys[key] = category
			end
		end

		local prompt = "Select a category or enter a new one:\n"
		for _, category in ipairs(category_list) do
			prompt = prompt .. string.format("[%s] %s\n", categories[category].key, category)
		end
		prompt = prompt .. "\nEnter a key or a new category: "

		vim.ui.input({
			prompt = prompt,
		}, function(input)
			if input then
				local selected_category = keys[input:lower()]
				if selected_category then
					AddTodoItemWithCategory(selected_category)
				else
					AddTodoItemWithCategory(input)
				end
			else
				print("No input provided.")
			end
		end)
	end
end

function M.AddTodoItemWithCategory(category)
	vim.ui.input({
		prompt = "Add item to '" .. category .. "':",
	}, function(item)
		if item then
			local file_path = os.getenv("HOME") .. "/.todo.json"
			local current_time = os.date("%Y-%m-%d %H:%M:%S")
			local todo_entry = {
				item = item,
				category = category,
				created = current_time,
				completed = false,
			}

			local file = io.open(file_path, "r")
			local todo_list = {}
			if file then
				local content = file:read("*all")
				file:close()
				if content ~= "" then
					todo_list = vim.fn.json_decode(content)
				end
			end

			table.insert(todo_list, todo_entry)

			local file = io.open(file_path, "w")
			if file then
				file:write(vim.fn.json_encode(todo_list))
				file:close()
				vim.notify("Todo item added successfully!", "info", { title = "Todo" })
			else
				vim.notify("Failed to write to file: " .. file_path, "error", { title = "Todo" })
			end
		else
			print("No todo item entered.")
		end
	end)
end

return M
