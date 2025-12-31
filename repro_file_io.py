import os

def check_io():
    filename = "test_io.txt"
    content_input = "Line1\r\nLine2"
    
    # Write with default text mode (Windows)
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content_input)
        
    # Read back
    with open(filename, 'r', encoding='utf-8') as f:
        read_content = f.read()
        
    print(f"Original: {repr(content_input)}")
    print(f"Read back: {repr(read_content)}")
    
    if "\r" in read_content and "\n" in read_content:
       # If it reads as 'Line1\n\nLine2' or similar
       print("Detected newline expansion.")
    
    if os.path.exists(filename):
        os.remove(filename)

check_io()
