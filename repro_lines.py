import os

def check_lines():
    title = "Test Title"
    meta_line = "META|weather:sunny|mood:happy"
    content = "Hello World"
    
    # Simulate Save 1
    file_content = f"{title}\n{meta_line}\n\n{content}"
    
    # Parse 1
    lines = file_content.splitlines(keepends=True)
    # read_diary logic
    content_start_index = 2
    if len(lines) > 1 and lines[1].startswith("META|"):
        content_start_index = 3
    
    read_content = "".join(lines[content_start_index:])
    print(f"Read 1: {repr(read_content)}")
    
    # Simulate Edit (User saves what they read)
    # The user submits 'read_content' back.
    content_2 = read_content
    file_content_2 = f"{title}\n{meta_line}\n\n{content_2}"
    
    # Parse 2
    lines_2 = file_content_2.splitlines(keepends=True)
    content_start_index_2 = 2
    if len(lines_2) > 1 and lines_2[1].startswith("META|"):
        content_start_index_2 = 3
    
    read_content_2 = "".join(lines_2[content_start_index_2:])
    print(f"Read 2: {repr(read_content_2)}")

    if read_content != read_content_2:
        print("FAIL: Content changed after save/read cycle.")
    else:
        print("SUCCESS: Content stable.")

check_lines()
