// Program.cs (single-file, WinForms, DirectShow-first property page launcher)

using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using System.Collections.Generic;

// NuGet: DirectShowLib (classic 1.0.0 works)
using DirectShowLib;

namespace UvcPaneler
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            AppLogger.Init();
            AppLogger.Info("UvcPaneler starting…");

            ApplicationConfiguration.Initialize();
            Application.Run(new MainForm());
        }
    }

    internal static class AppLogger
    {
        private static readonly object _lock = new object();
        private static string _logDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "UvcPaneler");
        private static string _logPath = Path.Combine(_logDir, "log.txt");
        private static int _maxBytes = 512 * 1024;

        public static void Init()
        {
            try
            {
                Directory.CreateDirectory(_logDir);
                RotateIfNeeded();
                Info("Logger initialized.");
            }
            catch
            {
                // swallow
            }
        }

        private static void RotateIfNeeded()
        {
            try
            {
                if (File.Exists(_logPath) && new FileInfo(_logPath).Length > _maxBytes)
                {
                    var backup = Path.Combine(_logDir, $"log_{DateTime.Now:yyyyMMdd_HHmmss}.txt");
                    File.Move(_logPath, backup);
                }
            }
            catch { }
        }

        public static void Info(string msg) => Write("INFO", msg);
        public static void Warn(string msg) => Write("WARN", msg);
        public static void Error(string msg) => Write("ERR ", msg);

        private static void Write(string level, string msg)
        {
            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{level}] {msg}";
            lock (_lock)
            {
                try
                {
                    File.AppendAllText(_logPath, line + Environment.NewLine, Encoding.UTF8);
                }
                catch { }
            }
            Debug.WriteLine(line);
        }
    }

    // VfW interfaces not in DirectShowLib 1.0.0 - define manually
    [ComImport, Guid("8E1C39A1-DE53-11cf-AA63-0080C744528D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAMVfwCaptureDialogs
    {
        [PreserveSig]
        int HasDialog([In] VfwCaptureDialogs iDialog);

        [PreserveSig]
        int ShowDialog([In] VfwCaptureDialogs iDialog, [In] IntPtr hwnd);

        [PreserveSig]
        int SendDriverMessage([In] VfwCaptureDialogs iDialog, [In] int uMsg, [In] int dw1, [In] int dw2);
    }

    internal enum VfwCaptureDialogs
    {
        Source = 0,
        Format = 1,
        Display = 2,
        Compression = 3
    }

    internal class MainForm : Form
    {
        private ListBox _lst;
        private Button _btnUvc;
        private Button _btnVfw;
        private Button _btnMf;
        private Button _btnShell;
        private Button _btnRefresh;
        private TextBox _log;
        private Label _hint;

        private class CamItem
        {
            public string Name { get; set; } = "";
            public string Moniker { get; set; } = "";
            public DsDevice Device { get; set; } = null!;
            public override string ToString() => Name;
        }

        public MainForm()
        {
            Text = "UvcPaneler — Camera Property Pages";
            Width = 900;
            Height = 600;
            StartPosition = FormStartPosition.CenterScreen;

            _lst = new ListBox { Left = 12, Top = 12, Width = 380, Height = 500 };
            _btnRefresh = new Button { Left = 12, Top = 520, Width = 120, Height = 30, Text = "Refresh" };

            _btnUvc = new Button { Left = 410, Top = 12, Width = 200, Height = 36, Text = "Open UVC (DirectShow)…" };
            _btnVfw = new Button { Left = 410, Top = 56, Width = 200, Height = 36, Text = "Open Legacy VfW…" };
            _btnMf  = new Button { Left = 410, Top = 100, Width = 200, Height = 36, Text = "Try MF (exploratory)…" };
            _btnShell = new Button { Left = 410, Top = 144, Width = 200, Height = 36, Text = "Device Manager…" };

            _hint = new Label
            {
                Left = 410, Top = 196, Width = 450, Height = 56,
                Text = "Tip: The “UVC (DirectShow)” button is the one that matched what you saw in NVIDIA Broadcast / e-CAM.",
                AutoSize = false
            };

            _log = new TextBox
            {
                Left = 410, Top = 260, Width = 450, Height = 272,
                Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true
            };

            Controls.AddRange(new Control[] { _lst, _btnRefresh, _btnUvc, _btnVfw, _btnMf, _btnShell, _hint, _log });

            _btnRefresh.Click += (_, __) => LoadCameras();
            _btnUvc.Click += (_, __) => OpenUvcPages();
            _btnVfw.Click += (_, __) => OpenVfwDialogs();
            _btnMf.Click  += (_, __) => TryMfExploratory();
            _btnShell.Click += (_, __) => OpenDeviceManager();

            LoadCameras();
        }

        private void AppendLog(string s)
        {
            AppLogger.Info(s);
            _log.AppendText(s + Environment.NewLine);
        }

        private void LoadCameras()
        {
            try
            {
                _lst.Items.Clear();

                var devs = DsDevice.GetDevicesOfCat(FilterCategory.VideoInputDevice) ?? Array.Empty<DsDevice>();
                foreach (var d in devs)
                {
                    // Name and DevicePath are the two most helpful identifiers
                    var name = d.Name ?? "(unnamed camera)";
                    var moniker = d.DevicePath ?? "(no moniker)";

                    _lst.Items.Add(new CamItem { Name = name, Moniker = moniker, Device = d });
                }
                AppendLog($"Found {_lst.Items.Count} camera(s).");
            }
            catch (Exception ex)
            {
                AppendLog($"Error enumerating cameras: {ex.Message}");
            }
        }

        private CamItem? Selected()
        {
            var it = _lst.SelectedItem as CamItem;
            if (it == null)
            {
                MessageBox.Show(this, "Pick a camera first.", "UvcPaneler", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return null;
            }
            return it;
        }

        #region DirectShow (UVC) property pages

        private void OpenUvcPages()
        {
            var it = Selected();
            if (it == null) return;

            AppendLog($"Opening UVC pages (DirectShow) for: {it.Name}");

            IBaseFilter? filter = null;
            try
            {
                filter = BindToFilter(it.Device);
                if (filter == null)
                {
                    AppendLog("Failed to bind to filter.");
                    MessageBox.Show(this, "Could not bind to the camera filter.", "UvcPaneler",
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                // Try ISpecifyPropertyPages (this is what you saw working)
                var specify = filter as ISpecifyPropertyPages;
                if (specify != null)
                {
                    DsCAUUID cauuid;
                    int hr = specify.GetPages(out cauuid);
                    DsError.ThrowExceptionForHR(hr);

                    object unk = filter;
                    // Show the same COM property frame other apps call
                    int hr2 = OleCreatePropertyFrame(
                        this.Handle, 0, 0, it.Name,
                        1, ref unk,
                        cauuid.cElems, cauuid.pElems,
                        0, 0, IntPtr.Zero);

                    Marshal.FreeCoTaskMem(cauuid.pElems);
                    DsError.ThrowExceptionForHR(hr2);

                    AppendLog("Property frame shown (ISpecifyPropertyPages).");
                    return;
                }

                AppendLog("ISpecifyPropertyPages not available, attempting VfW fallback…");
                OpenVfwDialogs(filter, it.Name);
            }
            catch (COMException cex)
            {
                AppendLog($"COM error opening UVC pages: 0x{cex.ErrorCode:X8} {cex.Message}");
                MessageBox.Show(this, "The camera didn't expose standard property pages on this path.", "UvcPaneler",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            catch (Exception ex)
            {
                AppendLog($"Error opening UVC pages: {ex.Message}");
                MessageBox.Show(this, ex.Message, "UvcPaneler", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                if (filter != null) Marshal.ReleaseComObject(filter);
            }
        }

        private static IBaseFilter? BindToFilter(DsDevice dev)
        {
            object? o = null;
            var iid = typeof(IBaseFilter).GUID;
#pragma warning disable CS8625 // COM interop allows null for these parameters
            dev.Mon.BindToObject(null, null, ref iid, out o);
#pragma warning restore CS8625
            return o as IBaseFilter;
        }

        [DllImport("oleaut32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int OleCreatePropertyFrame(
            IntPtr hwndOwner, int x, int y,
            string lpszCaption, int cObjects,
            [In, MarshalAs(UnmanagedType.Interface)] ref object ppUnk,
            int cPages, IntPtr pPageClsID, int lcid, int dwReserved, IntPtr pvReserved);

        #endregion

        #region Legacy VfW dialogs (DirectShow IAMVfwCaptureDialogs)

        private void OpenVfwDialogs()
        {
            var it = Selected();
            if (it == null) return;

            AppendLog($"Opening Legacy VfW path for: {it.Name}");
            IBaseFilter? filter = null;
            try
            {
                filter = BindToFilter(it.Device);
                if (filter == null)
                {
                    AppendLog("Failed to bind to filter.");
                    return;
                }
                OpenVfwDialogs(filter, it.Name);
            }
            catch (Exception ex)
            {
                AppendLog($"Error (VfW): {ex.Message}");
            }
            finally
            {
                if (filter != null) Marshal.ReleaseComObject(filter);
            }
        }

        private void OpenVfwDialogs(IBaseFilter filter, string name)
        {
            try
            {
                var vfw = filter as IAMVfwCaptureDialogs;
                if (vfw == null)
                {
                    AppendLog("IAMVfwCaptureDialogs not present on this device.");
                    MessageBox.Show(this,
                        "Legacy VfW dialogs not available on this camera.",
                        "UvcPaneler", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }

                // Try common VfW dialog types (some cams only implement a subset)
                var tried = new List<string>();
                foreach (var tuple in new (VfwCaptureDialogs dlg, string label)[]
                {
                    (VfwCaptureDialogs.Source, "Source"),
                    (VfwCaptureDialogs.Format, "Format"),
                    (VfwCaptureDialogs.Display, "Display"),
                    (VfwCaptureDialogs.Compression, "Compression"),
                })
                {
                    try
                    {
                        int has = vfw.HasDialog(tuple.dlg);
                        if (has != 0)
                        {
                            tried.Add(tuple.label);
                            vfw.ShowDialog(tuple.dlg, this.Handle);
                        }
                    }
                    catch (Exception vex)
                    {
                        AppendLog($"VfW {tuple.label} failed: {vex.Message}");
                    }
                }

                if (tried.Count > 0)
                {
                    AppendLog($"VfW dialogs shown: {string.Join(", ", tried)}");
                }
                else
                {
                    AppendLog("No VfW dialogs reported by the device.");
                    MessageBox.Show(this,
                        "The camera reported no legacy VfW dialogs.",
                        "UvcPaneler", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            }
            catch (COMException cex)
            {
                AppendLog($"COM error (VfW): 0x{cex.ErrorCode:X8} {cex.Message}");
            }
        }

        #endregion

        #region Media Foundation (informational / exploratory)

        private void TryMfExploratory()
        {
            var it = Selected();
            if (it == null) return;

            // In practice, most USB UVC cams still expose their config UI through
            // the same COM property pages we called above. MF capture stacks then
            // call into those property pages. So we log here and explain.
            AppendLog($"MF exploratory note for: {it.Name}");
            var msg =
                "Media Foundation note:\n\n" +
                "Most camera property UIs seen in MF-based apps are the device's COM property pages " +
                "(the same ones we open through DirectShow's ISpecifyPropertyPages). " +
                "Vendors ship one UI and expose it through COM; MF-based apps typically host that UI.\n\n" +
                "We already showed that UI via the UVC (DirectShow) button. If an MF-only device appears in the future, " +
                "we can add IMFActivate-based enumeration and attempt to query ISpecifyPropertyPages/IPropertyStore over the underlying driver object. " +
                "For your C920 and similar, the DirectShow path is the canonical route.";
            MessageBox.Show(this, msg, "Media Foundation", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        #endregion

        #region Shell / Device Manager fallback

        private void OpenDeviceManager()
        {
            try
            {
                AppendLog("Opening Device Manager (imaging devices).");
                // Class-specific launch (Device Manager). This opens DevMgmt; user can expand Cameras/Imaging devices.
                Process.Start(new ProcessStartInfo
                {
                    FileName = "devmgmt.msc",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                AppendLog($"Device Manager launch failed: {ex.Message}");
                MessageBox.Show(this, "Failed to open Device Manager.", "UvcPaneler",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        #endregion
    }
}
