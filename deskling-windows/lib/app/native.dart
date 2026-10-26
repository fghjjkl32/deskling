import 'dart:ffi';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../core/layout.dart';

class Monitor {
  const Monitor({required this.id, required this.bounds, required this.work, required this.scale, required this.isPrimary});

  /// Stable while the monitor stays connected: its position on the virtual desktop.
  final String id;
  final ScreenRect bounds;

  /// The bounds minus the taskbar.
  final ScreenRect work;

  /// 1.0 at 100 %, 1.5 at 150 %.
  final double scale;
  final bool isPrimary;
}

final _gdi32 = DynamicLibrary.open('gdi32.dll');

final _createRoundRectRgn = _gdi32.lookupFunction<IntPtr Function(Int32, Int32, Int32, Int32, Int32, Int32),
    int Function(int, int, int, int, int, int)>('CreateRoundRectRgn');
final _combineRgn =
    _gdi32.lookupFunction<Int32 Function(IntPtr, IntPtr, IntPtr, Int32), int Function(int, int, int, int)>('CombineRgn');

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _createMutex = _kernel32.lookupFunction<IntPtr Function(Pointer, Int32, Pointer<Utf16>),
    int Function(Pointer, int, Pointer<Utf16>)>('CreateMutexW');

const _rgnOr = 2;
const _swpFlags = SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER;

/// The few Win32 calls Flutter plugins do not cover. All coordinates are physical pixels.
class Native {
  Native._(this.hwnd);

  final int hwnd;

  /// Finds the Flutter runner window by its title, which `main.cpp` sets to `Deskling`.
  static Native? find() {
    final title = 'Deskling'.toNativeUtf16();
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    try {
      final hwnd = FindWindow(className, title);
      return hwnd == 0 ? null : Native._(hwnd);
    } finally {
      free(title);
      free(className);
    }
  }

  /// Keeps the pet out of the taskbar and Alt+Tab, and stops clicks from taking focus from the user's window.
  void makeToolWindow() {
    final style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, style | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
  }

  /// Returns false when only the position could be applied: Flutter keeps drawing at the old size after a
  /// resize while the window is hidden, which squeezes the pet and cuts off its head, so the size waits until it is shown.
  bool setFrame(ScreenRect frame) {
    final visible = IsWindowVisible(hwnd) != FALSE;
    SetWindowPos(hwnd, 0, frame.left, frame.top, frame.width, frame.height, _swpFlags | (visible ? 0 : SWP_NOSIZE));
    return visible;
  }

  /// Limits clicks (and drawing) to these rectangles; the rest of the window lets clicks through.
  /// Coordinates are relative to the window; each rectangle has its own corner diameter. Null clears the region.
  void setClickableArea(List<(ScreenRect, int)>? rects) {
    if (rects == null || rects.isEmpty) {
      SetWindowRgn(hwnd, NULL, TRUE);
      return;
    }
    final region = CreateRectRgn(0, 0, 0, 0);
    for (final (rect, corner) in rects) {
      final part = _createRoundRectRgn(rect.left, rect.top, rect.right + 1, rect.bottom + 1, corner, corner);
      _combineRgn(region, region, part, _rgnOr);
      DeleteObject(part);
    }
    // The system owns the region after this call, so it is not deleted here.
    SetWindowRgn(hwnd, region, TRUE);
  }

  /// Claims this app's named mutex for the life of the process; false when another Deskling holds it.
  /// Windows releases the mutex when the owner ends, even after a crash.
  static bool claimSingleInstance() {
    final name = r'Local\Deskling.SingleInstance'.toNativeUtf16();
    try {
      final mutex = _createMutex(nullptr, TRUE, name);
      if (mutex == 0) return true;
      // The first instance owns the mutex from creation, so its own wait succeeds; a later one times out.
      return WaitForSingleObject(mutex, 0) != WAIT_TIMEOUT;
    } finally {
      free(name);
    }
  }

  static Point<int> cursor() {
    final point = calloc<POINT>();
    try {
      GetCursorPos(point);
      return Point(point.ref.x, point.ref.y);
    } finally {
      free(point);
    }
  }

  static List<Monitor> monitors() {
    final handles = <int>[];
    final callback = NativeCallable<MONITORENUMPROC>.isolateLocal(
      (int monitor, int dc, Pointer rect, int data) {
        handles.add(monitor);
        return TRUE;
      },
      exceptionalReturn: 0,
    );
    try {
      EnumDisplayMonitors(NULL, nullptr, callback.nativeFunction, 0);
    } finally {
      callback.close();
    }
    final info = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();
    final dpiX = calloc<Uint32>();
    final dpiY = calloc<Uint32>();
    try {
      final result = <Monitor>[];
      for (final handle in handles) {
        if (GetMonitorInfo(handle, info) == 0) continue;
        final dpi = GetDpiForMonitor(handle, MDT_EFFECTIVE_DPI, dpiX, dpiY) == S_OK ? dpiX.value : 96;
        final m = info.ref.rcMonitor;
        final w = info.ref.rcWork;
        result.add(Monitor(
          id: '${m.left},${m.top}',
          bounds: ScreenRect(m.left, m.top, m.right, m.bottom),
          work: ScreenRect(w.left, w.top, w.right, w.bottom),
          scale: dpi / 96,
          isPrimary: info.ref.dwFlags & MONITORINFOF_PRIMARY != 0,
        ));
      }
      return result;
    } finally {
      free(info);
      free(dpiX);
      free(dpiY);
    }
  }

  /// True while the left mouse button is down, so a drag whose button-up was lost can still end.
  static bool get isLeftButtonDown => GetAsyncKeyState(VK_LBUTTON) & 0x8000 != 0;

  static void alert(String title, String body) {
    final text = body.toNativeUtf16();
    final caption = title.toNativeUtf16();
    try {
      MessageBox(NULL, text, caption, MB_OK | MB_ICONWARNING | MB_SETFOREGROUND | MB_TOPMOST);
    } finally {
      free(text);
      free(caption);
    }
  }
}
