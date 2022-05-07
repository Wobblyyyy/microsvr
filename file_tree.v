module file_tree

const (
	placeholder_path = '{{{PATH}}}'
	placeholder_list = '{{{LIST}}}'
	placeholder_href = '{{{HREF}}}'
	placeholder_text = '{{{TEXT}}}'
	tree_page_format = '
<!DOCTYPE html>
<html>
<head>
	<title>microsvr</title>
	<style>
		h1, a {
			font-family: "Lucida Console", "Courier New", monospace;
		}
	</style>
</head>
<body>
<h1>$placeholder_path</h1>
<ul>$placeholder_list</ul>
</body>
</html>
'
	list_element     = '<li><a href="$placeholder_href">$placeholder_text</a></li>'
)

pub fn get_list_element(href string, text string) string {
	return file_tree.list_element.replace(file_tree.placeholder_href, href).replace(file_tree.placeholder_text,
		text)
}

pub fn format_page(path string, list string) string {
	mut page := file_tree.tree_page_format

	page = page.replace(file_tree.placeholder_path, path)
	page = page.replace(file_tree.placeholder_list, list)

	return page
}

fn flatten_list(list []string) string {
	if list.len == 0 {
		return ''
	} else if list.len == 1 {
		return list[0]
	}

	mut ret := list[0] + '\n'

	for i in 1 .. list.len {
		ret += list[i] + '\n'
	}

	return '\n$ret'
}

pub fn get_tree_page(path string, parent string, children []string) string {
	mut list_elements := []string{}
	for i in 0 .. children.len {
		child := children[i]

		href := '../$child'
		text := '$child'

		list_elements << get_list_element(href, text)
	}

	return format_page(path, flatten_list(list_elements))
}
