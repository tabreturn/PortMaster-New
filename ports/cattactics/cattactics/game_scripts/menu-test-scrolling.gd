create_dynamic_menu("test2")
get_dynamic_menu("test2").add_item("Item A", "test1")
get_dynamic_menu("test2").add_item("Item B", "test2")
get_dynamic_menu("test2").add_item("Item C", "test3")
get_dynamic_menu("test2").add_item("Item D", "test4")
get_dynamic_menu("test2").add_item("Item E", "test5")
get_dynamic_menu("test2").add_item("Item F", "test6")
get_dynamic_menu("test2").add_item("Item G", "test7")
get_dynamic_menu("test2").add_item("Item H", "test8")
get_dynamic_menu("test2").add_item("Item I", "test9")
get_dynamic_menu("test2").add_item("Item J", "test10")
get_dynamic_menu("test2").add_item("Item K", "test11")
get_dynamic_menu("test2").set_position_layout("center")
show_dynamic_menu("test2")

textbox_auto_close(true)

textbox("selected: " + str(get_dynamic_menu_selected_text("test2")))
hide_textbox()
