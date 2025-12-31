import os
import sys
import uuid
import datetime
import threading
import webview
import base64
import json
from flask import Flask, render_template, request, redirect, url_for, jsonify

# --- 1. 资源路径处理 ---
CURRENT_VERSION = "1.3.0"

def resource_path(relative_path):
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

# --- 2. 数据存储路径处理 ---
if getattr(sys, 'frozen', False):
    BASE_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.abspath(".")

DATA_DIR = os.path.join(BASE_DIR, 'diary_data')
CONFIG_FILE = os.path.join(DATA_DIR, 'config.json')

app = Flask(__name__, template_folder=resource_path('templates'), static_folder=resource_path('static'))

if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

EXPORT_DIR = os.path.join(BASE_DIR, 'exports')
if not os.path.exists(EXPORT_DIR):
    os.makedirs(EXPORT_DIR)

# --- Config Management ---
def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {'theme': 'default'}
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except:
        return {'theme': 'default'}

def save_config(key, value):
    config = load_config()
    config[key] = value
    try:
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"Error saving config: {e}")

@app.route('/save_image', methods=['POST'])
def save_image():
    try:
        data = request.json
        image_data = data['image'].split(',')[1] 
        filename = f"diary_export_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        filepath = os.path.join(EXPORT_DIR, filename)
        
        with open(filepath, "wb") as fh:
            fh.write(base64.b64decode(image_data))
        
        # 返回绝对路径和友好的相对路径提示
        relative_display = os.path.join('exports', filename)
        return jsonify({
            'status': 'success', 
            'path': filepath,
            'display_path': relative_display
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

# --- 3. 业务逻辑 ---
def save_diary(date, title, weather, mood, content, is_markdown, original_filename=None):
    if not title: title = "无题"
    content = content.replace('\r\n', '\n')
    meta_line = f"META|weather:{weather}|mood:{mood}|markdown:{is_markdown}"
    file_content = f"{title}\n{meta_line}\n\n{content}"

    if original_filename and os.path.exists(os.path.join(DATA_DIR, original_filename)):
        filename = original_filename
    else:
        unique_id = str(uuid.uuid4())[:8]
        filename = f"{date}_{unique_id}.txt"

    filepath = os.path.join(DATA_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(file_content)
    return filename

def read_diary(filename):
    filepath = os.path.join(DATA_DIR, filename)
    if not os.path.exists(filepath): return None
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    if not lines: return None
    
    title = lines[0].strip()
    weather = "sunny"; mood = "calm"; is_markdown = "false"; content_start_index = 2
    if len(lines) > 1 and lines[1].startswith("META|"):
        try:
            parts = lines[1].strip().split('|')
            for p in parts:
                if 'weather:' in p: weather = p.split(':')[1].strip()
                if 'mood:' in p: mood = p.split(':')[1].strip()
                if 'markdown:' in p: is_markdown = p.split(':')[1].strip()
            content_start_index = 3
        except: pass
            
    content = "".join(lines[content_start_index:])
    base_name = filename.replace('.txt', '')
    date_str = base_name.split('_')[0] if '_' in base_name else base_name
    preview = content[:50].replace('\n', ' ') + "..." if len(content) > 50 else content
    
    weather_map = {'sunny': '晴', 'cloudy': '多云', 'rainy': '雨', 'snowy': '雪', 'windy': '风'}
    mood_map = {'happy': '开心', 'calm': '平静', 'sad': '忧郁', 'excited': '激动', 'tired': '疲惫'}

    return {'filename': filename, 'date': date_str, 'title': title, 'weather': weather, 'mood': mood, 'is_markdown': is_markdown,
            'weather_zh': weather_map.get(weather, weather), 'mood_zh': mood_map.get(mood, mood),
            'content': content, 'preview': preview}

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        filename = request.form.get('filename')
        if request.form.get('content'):
            is_markdown = request.form.get('is_markdown', 'false')
            saved = save_diary(request.form.get('date'), request.form.get('title'), request.form.get('weather'), 
                             request.form.get('mood'), request.form.get('content'), is_markdown, filename)
            return redirect(url_for('index', view='read', file=saved))

    files = [f for f in os.listdir(DATA_DIR) if f.endswith('.txt')]
    diary_list = []
    search_query = request.args.get('q')
    
    for f in files:
        entry = read_diary(f)
        if entry:
            if search_query:
                if search_query in entry['title'] or search_query in entry['content'] or search_query in entry['date']:
                    diary_list.append(entry)
            else:
                diary_list.append(entry)
    
    diary_list.sort(key=lambda x: (x['date'], x['filename']), reverse=True)

    view = request.args.get('view', 'list')
    load_file = request.args.get('file')
    data = {'filename': '', 'date': datetime.date.today().strftime("%Y-%m-%d"), 'title': '', 'content': '', 'weather': 'sunny', 'mood': 'calm', 'is_markdown': 'false'}
    
    show_read = (view == 'read' and load_file is not None)
    show_edit = (view == 'edit')
    show_list = (not show_read and not show_edit)

    if load_file:
        entry = read_diary(load_file)
        if entry: data = entry

    # Inject Current Theme
    user_config = load_config()
    current_theme = user_config.get('theme', 'default')
    if current_theme == 'zen': current_theme = 'sea_flower'

    # Version Check
    last_version = user_config.get('last_seen_version', '0.0.0')
    show_update_modal = (last_version != CURRENT_VERSION)

    return render_template('index.html', diary_list=diary_list, show_list=show_list, 
                           show_read=show_read, show_edit=show_edit, data=data, search_query=search_query,
                           current_theme=current_theme, show_update_modal=show_update_modal, current_version=CURRENT_VERSION)

@app.route('/api/setting', methods=['POST'])
def update_setting():
    data = request.json
    if 'theme' in data:
        save_config('theme', data['theme'])
    if 'last_seen_version' in data:
        save_config('last_seen_version', data['last_seen_version'])
    return jsonify({'status': 'success'})

@app.route('/delete')
def delete_diary():
    f = request.args.get('file')
    if f and os.path.exists(os.path.join(DATA_DIR, f)): os.remove(os.path.join(DATA_DIR, f))
    return redirect('/')

# --- 4. 启动逻辑 ---
def start_server():
    app.run(host='127.0.0.1', port=54321, debug=False)

if __name__ == '__main__':
    t = threading.Thread(target=start_server)
    t.daemon = True
    t.start()

    # WebView Configuration
    CACHE_DIR = os.path.join(BASE_DIR, 'webview_cache')
    if not os.path.exists(CACHE_DIR):
        os.makedirs(CACHE_DIR)

    webview.create_window('纸语 PaperWhisper', 'http://127.0.0.1:54321', width=1280, height=850, min_size=(900, 600))
    webview.start(storage_path=CACHE_DIR, private_mode=False)