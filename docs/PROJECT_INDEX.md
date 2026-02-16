# Project Development Index / 项目开发索引

This file serves as a map to navigate the codebase, facilitating future development and maintenance.
该文件作为代码库的导航地图，旨在方便后续的开发和维护工作。

## 📂 Project Root (Python/Webview Backend)
The root directory contains a Python-based application (likely a desktop wrapper or server) and auxiliary scripts.
根目录包含一个基于 Python 的应用程序（可能是桌面封装或服务端）以及辅助脚本。

| File/Directory | Description (说明) |
| :--- | :--- |
| `app.py` | Main Python entry point using Flask & pywebview. Handles local data storage (`diary_data`) and UI rendering. <br> Python 主程序入口，使用 Flask 和 pywebview。处理本地数据存储和 UI 渲染。 |
| `backend/` | Contains Node.js worker scripts (e.g., `generate_codes.js`, `worker.js`) for background tasks. <br> 包含 Node.js 工作脚本，用于后台任务。 |
| `cloud_workers/` | Scripts related to cloud function deployment or execution. <br> 云函数部署或执行相关脚本。 |
| `static/` | Static assets (CSS, JS) for the Flask application. <br> Flask 应用的静态资源（CSS, JS）。 |
| `templates/` | HTML templates for the Flask application. <br> Flask 应用的 HTML 模板。 |
| `docs/` | Documentation files. <br> 文档文件。 |
| `releases/` | Build artifacts or release information. <br> 构建产物或发布信息。 |

---

## 📱 Flutter Application (`paper_whisper_flutter/`)
The main modern application source code, built with Flutter for Cross-Platform (Windows/Android).
主要的现代化应用源代码，使用 Flutter 构建，支持跨平台（Windows/Android）。

### 🏗 Core Structure (核心结构)

| Directory | Description (说明) |
| :--- | :--- |
| **`lib/`** | **Main Source Code (源码目录)** |
| `lib/main.dart` | **App Entry Point**. Initializes providers, themes, and routing. <br> **应用入口**。初始化 Provider、主题和路由。 |
| `lib/config/` | App-wide configuration, themes (`app_theme.dart`), and constants. <br> 全局配置、主题和常量。 |
| `lib/models/` | Data models (e.g., `diary_entry.dart`, `moment.dart`, `sync_config.dart`). <br> 数据模型定义。 |
| `lib/utils/` | Utility functions (platform checks, formatters). <br> 工具函数（平台检测、格式化等）。 |

### 🧩 Key Feature Modules (关键功能模块)

#### 1. Pages (`lib/pages/`) - UI Screens
| File | Responsibility |
| :--- | :--- |
| `editor_page.dart` | The main diary editor interface. <br> 日记编辑器主界面。 |
| `moments_page.dart` | The "Moments" feed (chat-style logging). <br> “随心记”流界面（聊天式记录）。 |
| `diary_list_page.dart` | List of diary entries. <br> 日记列表。 |
| `settings_page.dart` | Application settings. <br> 应用设置。 |
| `sync_settings_page.dart`| WebDAV/Cloud sync configuration. <br> 同步设置配置。 |

#### 2. Services (`lib/services/`) - Business Logic
| File | Responsibility |
| :--- | :--- |
| `diary_service.dart` | CRUD operations for diary entries. <br> 日记条目的增删改查。 |
| `sync_service.dart` | Handles data synchronization logic. <br> 处理数据同步逻辑。 |
| `webdav_sync_service.dart`| Specific WebDAV protocol implementation. <br> WebDAV 协议具体实现。 |
| `auth_service.dart` | Authentication and security. <br> 认证与安全。 |
| `cloud_storage_service.dart`| Interface for cloud storage operations. <br> 云存储操作接口。 |

#### 3. Widgets (`lib/widgets/`) - Reusable Components
*Focuses on Skeuomorphic (Real-world style) elements.*
*专注于拟物化风格组件。*

| File | Responsibility |
| :--- | :--- |
| `skeuomorphic_*.dart` | Custom skeuomorphic UI components (containers, dialogs, etc.). <br> 自定义拟物化 UI 组件。 |
| `moment_card.dart` | Display card for individual moments. <br> 单条随心记的展示卡片。 |
| `cassette_wheel.dart` | Tape recorder animation/interaction. <br> 磁带录音机动画/交互。 |
| `book_flip_*.dart` | Page turning animations. <br> 翻页动画效果。 |

### 📦 Assets & Configuration
- `pubspec.yaml`: Dart dependencies.
- `assets/`: 
  - `illustrations/`: SVG illustrations.
  - `textures/`: Background textures (paper, leather) for skeuomorphism.
  - `fonts/`: Custom fonts.

### 🔧 Platform Specifics
- `android/`: Android-specific build configuration.
- `windows/`: Windows C++ runner and configuration.
