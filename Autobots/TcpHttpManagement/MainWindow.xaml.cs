﻿using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace TcpHttpManagement
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window, INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler PropertyChanged;
        public void NotifyPropertyChanged(string propertyName)
        {
            if (PropertyChanged != null)
                PropertyChanged(this, new PropertyChangedEventArgs(propertyName));
        }

        #region Const

        private const string DEF_LOG_FOLDER = @"C:";

        private const int MSG_HEADER_LENGTH = 6;

        private const int MIN_LOG_COUNT = 100;
        private const int DEF_LOG_COUNT = 1000;
        private const int MAX_LOG_COUNT = 10000;
        private const int MAX_STATUS_PBAR_MAX_VALUE = 100;
        //private const int DEF_SERVER_PORT = 5081;
        //private const int MIN_SERVER_PORT = 1;

        //private const int LOG_SAVE_INDI_COUNT = 1000;

        private const int DEF_AUTO_INTERVAL = 30;
        private const string DEF_SERVER_IP = "127.0.0.1";
        private const string DEF_SERVER_PORT = "5081";
        private const double DEF_HTTP_DISPATCHER_SLEEP_TIME = 10.0;  // minute

        private const int MT_TCP_RECEIVE_TIMEOUT = 30000;

        private const int STOP_MANAGE_WAITING_TIME = 1;

        //
        // Messages from management terminal
        //
        private const string MT_UNK_REQ = "019999";
        private const string MT_QRY_ALL_STATES = "010000";
        private const string MT_RST_ALL_STATES = "010001";
        private const string MT_QRY_ALL_2HTTP = "010002";
        private const string MT_QRY_ALL_2HTTP_COUNT = "010029";
        private const string MT_QRY_ALL_2HTTP_CLR = "010005";
        private const string MT_QRY_ALL_2JIT = "010003";
        private const string MT_QRY_ALL_2TERM = "010004";
        private const string MT_QRY_ALL_2JIT_CLR = "010006";
        private const string MT_QRY_ALL_2TERM_CLR = "010007";
        private const string MT_CLR_ALL_2HTTP = "010008";
        private const string MT_CLR_ALL_2JIT = "010009";
        private const string MT_CLR_ALL_2TERM = "010010";
        private const string MT_QRY_DISPLAY_LOG_STATE = "010011";
        private const string MT_SET_DISPLAY_LOG_STATE = "010012";
        private const string MT_QRY_USE_MASTER_STATE = "010013";
        private const string MT_SET_USE_MASTER_STATE = "010014";
        private const string MT_QRY_ACC_TERM_CONT_FAIL = "010019";
        private const string MT_CLR_ACC_TERM_CONT_FAIL = "010020";
        private const string MT_QRY_ACC_TERM_TOTAL_FAIL = "010021";
        private const string MT_CLR_ACC_TERM_TOTAL_FAIL = "010022";
        private const string MT_QRY_ACC_MT_CONT_FAIL = "010023";
        private const string MT_CLR_ACC_MT_CONT_FAIL = "010024";
        private const string MT_QRY_ACC_MT_TOTAL_FAIL = "010025";
        private const string MT_CLR_ACC_MT_TOTAL_FAIL = "010026";
        private const string MT_QRY_LOG_LEVEL = "010027";
        private const string MT_SET_LOG_LEVEL = "010028";
        private const string MT_QRY_ALL_2JIT_COUNT = "010030";
        private const string MT_QRY_ALL_2TERM_COUNT = "010031";
        private const string MT_QRY_ALL_LOG = "010032";
        private const string MT_QRY_ALL_LOG_CLR = "010033";
        private const string MT_QRY_ALL_LOG_COUNT = "010034";
        private const string MT_CLR_ALL_LOG = "010035";
        private const string MT_QRY_ALL_MT = "010036";
        private const string MT_QRY_ALL_MT_COUNT = "010037";
        private const string MT_QRY_ORI_DISPLAY_LOG_STATE = "000038";
        private const string MT_QRY_ORI_LOG_LEVEL = "000039";
        private const string MT_QRY_ALL_TERM = "010040";
        private const string MT_QRY_ALL_TERM_COUNT = "010041";
        private const string MT_QRY_NORMAL_HTTP_PROC_COUNT = "010042";
        private const string MT_QRY_IDLE_HTTP_PROC_COUNT = "010043";
        private const string MT_QRY_HTTP_PROC_MAX_COUNT = "010044";
        private const string MT_QRY_HTTP_PROC_WARN_COUNT = "010045";
        private const string MT_SET_HTTP_PROC_MAX_COUNT = "010046";
        private const string MT_SET_HTTP_PROC_WARN_COUNT = "010047";
        private const string MT_SAV_ALL_2JIT = "010048";
        private const string MT_QRY_SAV_ALL_2JIT = "010049";
        private const string MT_QRY_SAV_ALL_2JIT_COUNT = "010050";
        private const string MT_RES_ALL_2JIT = "010051";
        private const string MT_SAV_ALL_2TERM = "010048";
        private const string MT_QRY_SAV_ALL_2TERM = "010049";
        private const string MT_QRY_SAV_ALL_2TERM_COUNT = "010050";
        private const string MT_RES_ALL_2TERM = "010051";
        private const string MT_QRY_HTTP_DISPATCHER_TIME = "010052";
        private const string MT_QRY_MASTER_JIT_CONT_FAIL = "010054";
        private const string MT_CLR_MASTER_JIT_CONT_FAIL = "010055";
        private const string MT_QRY_MASTER_JIT_TOTAL_FAIL = "010056";
        private const string MT_CLR_MASTER_JIT_TOTAL_FAIL = "010057";
        private const string MT_QRY_BOTH_JIT_CONT_FAIL = "010058";
        private const string MT_CLR_BOTH_JIT_CONT_FAIL = "010059";
        private const string MT_QRY_BOTH_JIT_TOTAL_FAIL = "010060";
        private const string MT_CLR_BOTH_JIT_TOTAL_FAIL = "010061";

        //
        // Messages ok to management terminal
        //
        private const string MT_UNK_REQ_OK = "029999";
        private const string MT_QRY_ALL_STATES_OK = "020000";
        private const string MT_RST_ALL_STATES_OK = "020001";
        private const string MT_QRY_ALL_2HTTP_OK = "020002";
        private const string MT_QRY_ALL_2JIT_OK = "020003";
        private const string MT_QRY_ALL_2TERM_OK = "020004";
        private const string MT_QRY_ALL_2HTTP_CLR_OK = "020005";
        private const string MT_QRY_ALL_2JIT_CLR_OK = "020006";
        private const string MT_QRY_ALL_2TERM_CLR_OK = "020007";
        private const string MT_CLR_ALL_2HTTP_OK = "020008";
        private const string MT_CLR_ALL_2JIT_OK = "020009";
        private const string MT_CLR_ALL_2TERM_OK = "020010";
        private const string MT_QRY_DISPLAY_LOG_STATE_OK = "020011";
        private const string MT_SET_DISPLAY_LOG_STATE_OK = "020012";
        private const string MT_QRY_USE_MASTER_STATE_OK = "020013";
        private const string MT_SET_USE_MASTER_STATE_OK = "020014";
        private const string MT_QRY_ACC_TERM_CONT_FAIL_OK = "020019";
        private const string MT_CLR_ACC_TERM_CONT_FAIL_OK = "020020";
        private const string MT_QRY_ACC_TERM_TOTAL_FAIL_OK = "020021";
        private const string MT_CLR_ACC_TERM_TOTAL_FAIL_OK = "020022";
        private const string MT_QRY_ACC_MT_CONT_FAIL_OK = "020023";
        private const string MT_CLR_ACC_MT_CONT_FAIL_OK = "020024";
        private const string MT_QRY_ACC_MT_TOTAL_FAIL_OK = "020025";
        private const string MT_CLR_ACC_MT_TOTAL_FAIL_OK = "020026";
        private const string MT_QRY_LOG_LEVEL_OK = "020027";
        private const string MT_SET_LOG_LEVEL_OK = "020028";
        private const string MT_QRY_ALL_2HTTP_COUNT_OK = "020029";
        private const string MT_QRY_ALL_2JIT_COUNT_OK = "020030";
        private const string MT_QRY_ALL_2TERM_COUNT_OK = "020031";
        private const string MT_QRY_ALL_LOG_OK = "020032";
        private const string MT_QRY_ALL_LOG_CLR_OK = "020033";
        private const string MT_QRY_ALL_LOG_COUNT_OK = "020034";
        private const string MT_CLR_ALL_LOG_OK = "020035";
        private const string MT_QRY_ALL_MT_OK = "020036";
        private const string MT_QRY_ALL_MT_COUNT_OK = "020037";
        private const string MT_QRY_ORI_DISPLAY_LOG_STATE_OK = "020038";
        private const string MT_QRY_ORI_LOG_LEVEL_OK = "020039";
        private const string MT_QRY_ALL_TERM_OK = "020040";
        private const string MT_QRY_ALL_TERM_COUNT_OK = "020041";
        private const string MT_QRY_NORMAL_HTTP_PROC_COUNT_OK = "020042";
        private const string MT_QRY_IDLE_HTTP_PROC_COUNT_OK = "020043";
        private const string MT_QRY_HTTP_PROC_MAX_COUNT_OK = "020044";
        private const string MT_QRY_HTTP_PROC_WARN_COUNT_OK = "020045";
        private const string MT_SET_HTTP_PROC_MAX_COUNT_OK = "020046";
        private const string MT_SET_HTTP_PROC_WARN_COUNT_OK = "020047";
        private const string MT_SAV_ALL_2JIT_OK = "020048";
        private const string MT_QRY_SAV_ALL_2JIT_OK = "020049";
        private const string MT_QRY_SAV_ALL_2JIT_COUNT_OK = "020050";
        private const string MT_RES_ALL_2JIT_OK = "020051";
        private const string MT_SAV_ALL_2TERM_OK = "020048";
        private const string MT_QRY_SAV_ALL_2TERM_OK = "020049";
        private const string MT_QRY_SAV_ALL_2TERM_COUNT_OK = "020050";
        private const string MT_RES_ALL_2TERM_OK = "020051";
        private const string MT_QRY_HTTP_DISPATCHER_TIME_OK = "020052";
        private const string MT_QRY_MASTER_JIT_CONT_FAIL_OK = "020054";
        private const string MT_CLR_MASTER_JIT_CONT_FAIL_OK = "020055";
        private const string MT_QRY_MASTER_JIT_TOTAL_FAIL_OK = "020056";
        private const string MT_CLR_MASTER_JIT_TOTAL_FAIL_OK = "020057";
        private const string MT_QRY_BOTH_JIT_CONT_FAIL_OK = "020058";
        private const string MT_CLR_BOTH_JIT_CONT_FAIL_OK = "020059";
        private const string MT_QRY_BOTH_JIT_TOTAL_FAIL_OK = "020060";
        private const string MT_CLR_BOTH_JIT_TOTAL_FAIL_OK = "020061";

        //
        // Messages error to management terminal
        //
        private const string MT_UNK_REQ_ERR = "039999";
        private const string MT_QRY_ALL_STATES_ERR = "030000";
        private const string MT_RST_ALL_STATES_ERR = "030001";
        private const string MT_QRY_ALL_2HTTP_ERR = "030002";
        private const string MT_QRY_ALL_2JIT_ERR = "030003";
        private const string MT_QRY_ALL_2TERM_ERR = "030004";
        private const string MT_QRY_ALL_2HTTP_CLR_ERR = "030005";
        private const string MT_QRY_ALL_2JIT_CLR_ERR = "030006";
        private const string MT_QRY_ALL_2TERM_CLR_ERR = "030007";
        private const string MT_CLR_ALL_2HTTP_ERR = "030008";
        private const string MT_CLR_ALL_2JIT_ERR = "030009";
        private const string MT_CLR_ALL_2TERM_ERR = "030010";
        private const string MT_QRY_DISPLAY_LOG_STATE_ERR = "030011";
        private const string MT_SET_DISPLAY_LOG_STATE_ERR = "030012";
        private const string MT_QRY_USE_MASTER_STATE_ERR = "030013";
        private const string MT_SET_USE_MASTER_STATE_ERR = "030014";
        private const string MT_QRY_ACC_TERM_CONT_FAIL_ERR = "030019";
        private const string MT_CLR_ACC_TERM_CONT_FAIL_ERR = "030020";
        private const string MT_QRY_ACC_TERM_TOTAL_FAIL_ERR = "030021";
        private const string MT_CLR_ACC_TERM_TOTAL_FAIL_ERR = "030022";
        private const string MT_QRY_ACC_MT_CONT_FAIL_ERR = "030023";
        private const string MT_CLR_ACC_MT_CONT_FAIL_ERR = "030024";
        private const string MT_QRY_ACC_MT_TOTAL_FAIL_ERR = "030025";
        private const string MT_CLR_ACC_MT_TOTAL_FAIL_ERR = "030026";
        private const string MT_QRY_LOG_LEVEL_ERR = "030027";
        private const string MT_SET_LOG_LEVEL_ERR = "030028";
        private const string MT_QRY_ALL_2HTTP_COUNT_ERR = "030029";
        private const string MT_QRY_ALL_2JIT_COUNT_ERR = "030030";
        private const string MT_QRY_ALL_2TERM_COUNT_ERR = "030031";
        private const string MT_QRY_ALL_LOG_ERR = "030032";
        private const string MT_QRY_ALL_LOG_CLR_ERR = "030033";
        private const string MT_QRY_ALL_LOG_COUNT_ERR = "030034";
        private const string MT_CLR_ALL_LOG_ERR = "030035";
        private const string MT_QRY_ALL_MT_ERR = "030036";
        private const string MT_QRY_ALL_MT_COUNT_ERR = "030037";
        private const string MT_QRY_ORI_DISPLAY_LOG_STATE_ERR = "030038";
        private const string MT_QRY_ORI_LOG_LEVEL_ERR = "030039";
        private const string MT_QRY_ALL_TERM_ERR = "030040";
        private const string MT_QRY_ALL_TERM_COUNT_ERR = "030041";
        private const string MT_QRY_NORMAL_HTTP_PROC_COUNT_ERR = "0320042";
        private const string MT_QRY_IDLE_HTTP_PROC_COUNT_ERR = "030043";
        private const string MT_QRY_HTTP_PROC_MAX_COUNT_ERR = "030044";
        private const string MT_QRY_HTTP_PROC_WARN_COUNT_ERR = "030045";
        private const string MT_SET_HTTP_PROC_MAX_COUNT_ERR = "030046";
        private const string MT_SET_HTTP_PROC_WARN_COUNT_ERR = "030047";
        private const string MT_SAV_ALL_2JIT_ERR = "030048";
        private const string MT_QRY_SAV_ALL_2JIT_ERR = "030049";
        private const string MT_QRY_SAV_ALL_2JIT_COUNT_ERR = "030050";
        private const string MT_RES_ALL_2JIT_ERR = "030051";
        private const string MT_SAV_ALL_2TERM_ERR = "030048";
        private const string MT_QRY_SAV_ALL_2TERM_ERR = "030049";
        private const string MT_QRY_SAV_ALL_2TERM_COUNT_ERR = "030050";
        private const string MT_RES_ALL_2TERM_ERR = "030051";
        private const string MT_QRY_HTTP_DISPATCHER_TIME_ERR = "030052";
        private const string MT_QRY_MASTER_JIT_CONT_FAIL_ERR = "030054";
        private const string MT_CLR_MASTER_JIT_CONT_FAIL_ERR = "030055";
        private const string MT_QRY_MASTER_JIT_TOTAL_FAIL_ERR = "030056";
        private const string MT_CLR_MASTER_JIT_TOTAL_FAIL_ERR = "030057";
        private const string MT_QRY_BOTH_JIT_CONT_FAIL_ERR = "030058";
        private const string MT_CLR_BOTH_JIT_CONT_FAIL_ERR = "030059";
        private const string MT_QRY_BOTH_JIT_TOTAL_FAIL_ERR = "030060";
        private const string MT_CLR_BOTH_JIT_TOTAL_FAIL_ERR = "030061";

        #endregion

        #region Variables

        private int[] _maxLogCountArray = new int[]
		{
			0,
			100,
			200,
			500,
			1000
		};

        private int[] _saveLogCountArray = new int[]
		{
			100,
			500,
			1000,
            5000,
            10000,
            -1
		};

        private string[] _logType = new string[]
		{
			"Info,Warn,Err",
			"Warn,Err",
			"Err",
			"None"
		};

        private object _objLock = new object();
        private bool _bInNormalClose = false;
        private Timer _manageTimer = null;
        private Task _manageTask = null;
        private CancellationTokenSource _manageCts = null;
        private Socket _manageClient = null;

        private object _objReqLock = new object();
        private Queue<string> _requestQueue = new Queue<string>();
        private byte[] _recBuffer = new byte[1024 * 64];

        #endregion

        #region Properties

        private int _managementTabSelected = 0;
        public int ManagementTabSelected
        {
            get
            {
                return _managementTabSelected;
            }
            set
            {
                _managementTabSelected = value;
                NotifyPropertyChanged("ManagementTabSelected");
            }
        }

        private ObservableCollection<LogItem> _logOc = new ObservableCollection<LogItem>();
        private ObservableCollection<LogItem> _logDispOc = new ObservableCollection<LogItem>();
        public ObservableCollection<LogItem> LogDisplayOc
        {
            get
            {
                return _logDispOc;
            }
        }

        private string _logFolder = DEF_LOG_FOLDER;
        public string LogFolder
        {
            get
            {
                return _logFolder;
            }
            set
            {
                if (Directory.Exists(value) == false)
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Default Log Folder : " + value);
                else
                {
                    PrevLogFoler = _logFolder;
                    _logFolder = value;
                }
                NotifyPropertyChanged("LogFolder");
            }
        }

        private string _prevLogFolder = DEF_LOG_FOLDER;
        public string PrevLogFoler
        {
            get
            {
                return _prevLogFolder;
            }
            set
            {
                _prevLogFolder = value;
                NotifyPropertyChanged("PrevLogFoler");
            }
        }

        public string ServerInfo
        {
            get
            {
                return "Server - " + ServerIP + ":" + ServerPort + " - every " + AutoInterval.ToString() + " s";
            }
        }

        private bool _serverValid = false;
        public bool ServerValid
        {
            get
            {
                return _serverValid;
            }
            set
            {
                _serverValid = value;
                if (_serverValid == false)
                    ServerInfoFG = Brushes.Red;
                else
                    ServerInfoFG = Brushes.DarkGreen;
                NotifyPropertyChanged("ServerValid");
            }
        }

        private SolidColorBrush _serverInfoFG = Brushes.Red;
        public SolidColorBrush ServerInfoFG
        {
            get
            {
                return _serverInfoFG;
            }
            set
            {
                _serverInfoFG = value;
                NotifyPropertyChanged("ServerInfoFG");
            }
        }

        private string _statusBarInfo = "Ready";
        public string StatusBarInfo
        {
            get
            {
                return _statusBarInfo;
            }
            set
            {
                _statusBarInfo = value;
                NotifyPropertyChanged("StatusBarInfo");
            }
        }

        private int _statusPbarValue = 0;
        public int StatusPbarValue
        {
            get
            {
                return _statusPbarValue;
            }
            set
            {
                _statusPbarValue = value;
                if (_statusPbarValue < 0)
                    _statusPbarValue = 0;
                else if (_statusPbarValue > MAX_STATUS_PBAR_MAX_VALUE)
                    _statusPbarValue = MAX_STATUS_PBAR_MAX_VALUE;
                NotifyPropertyChanged("StatusPbarValue");
            }
        }

        /// <summary>
        /// Never get/set this value because it is used for UI and please use CurrentMaxLogCount
        /// </summary>
        private int _maxLogCountSelectedIndex = 3;
        /// <summary>
        /// Never get/set this value because it is used for UI and please use CurrentMaxLogCount
        /// </summary>
        public int MaxLogCountSelectedIndex
        {
            get
            {
                return _maxLogCountSelectedIndex;
            }
            set
            {
                _maxLogCountSelectedIndex = value;
                NotifyPropertyChanged("MaxLogCountSelectedIndex");
            }
        }

        public int CurrentMaxLogCount
        {
            get
            {
                return _maxLogCountArray[MaxLogCountSelectedIndex];
            }
        }

        /// <summary>
        /// Never get/set this value because it is used for UI and please use CurrentMaxLogCount
        /// </summary>
        private int _saveLogCountSelectedIndex = 2;
        /// <summary>
        /// Never get/set this value because it is used for UI and please use CurrentMaxLogCount
        /// </summary>
        public int SaveLogCountSelectedIndex
        {
            get
            {
                return _saveLogCountSelectedIndex;
            }
            set
            {
                _saveLogCountSelectedIndex = value;
                NotifyPropertyChanged("SaveLogCountSelectedIndex");
            }
        }

        public int CurrentSaveLogCount
        {
            get
            {
                return _saveLogCountArray[SaveLogCountSelectedIndex];
            }
        }

        /// <summary>
        /// Never get/set this value because it is used for UI and please use LogIsAutoScrolling
        /// </summary>
        private bool? _logAutoScrollingEnabled = true;
        /// <summary>
        /// Never get/set this value because it is used for UI and please use LogIsAutoScrolling
        /// </summary>
        public bool? LogAutoScrollingEnabled
        {
            get
            {
                return _logAutoScrollingEnabled;
            }
            set
            {
                if (value == null)
                    _logAutoScrollingEnabled = false;
                else
                    _logAutoScrollingEnabled = value;
                NotifyPropertyChanged("LogAutoScrollingEnabled");
            }
        }

        public bool LogIsAutoScrolling
        {
            get
            {
                if (LogAutoScrollingEnabled == null)
                    return false;
                else
                    return (bool)LogAutoScrollingEnabled;
            }
        }

        private string _serverIP = DEF_SERVER_IP;
        public string ServerIP
        {
            get
            {
                return _serverIP;
            }
            set
            {
                _serverIP = value;
                NotifyPropertyChanged("ServerIP");
                NotifyPropertyChanged("ServerInfo");
            }
        }

        private string _serverPort = DEF_SERVER_PORT;
        public string ServerPort
        {
            get
            {
                return _serverPort;
            }
            set
            {
                _serverPort = value;
                NotifyPropertyChanged("ServerPort");
                NotifyPropertyChanged("ServerInfo");
            }
        }

        private int _autoInterval = DEF_AUTO_INTERVAL;
        public int AutoInterval
        {
            get
            {
                return _autoInterval;
            }
            set
            {
                _autoInterval = value;
                NotifyPropertyChanged("AutoInterval");
                NotifyPropertyChanged("ServerInfo");
            }
        }

        private bool _inRun = false;
        public bool InRun
        {
            get
            {
                return _inRun;
            }
            set
            {
                _inRun = value;
                NotifyPropertyChanged("InRun");
                NotifyPropertyChanged("NotInRun");
                if (_inRun == true)
                    StatusBarInfo = "Server - " + ServerIP + ":" + ServerPort + " - every " + AutoInterval.ToString() + " s";
                else
                    StatusBarInfo = "Ready";
            }
        }

        public bool NotInRun
        {
            get
            {
                return !_inRun;
            }
        }

        private bool HasRequest
        {
            get
            {
                lock (_objReqLock)
                {
                    return _requestQueue.Count > 0;
                }
            }
        }

        private string _msg2Http = "";
        public string Msg2Http
        {
            get
            {
                return _msg2Http;
            }
            set
            {
                _msg2Http = value;
                int count = 0;
                if (int.TryParse(_msg2Http, out count) == false)
                    Msg2HttpFG = Brushes.Red;
                else if (count != 0)
                    Msg2HttpFG = Brushes.Red;
                else
                    Msg2HttpFG = Brushes.Black;
                NotifyPropertyChanged("Msg2Http");
            }
        }

        private SolidColorBrush _msg2HttpFG = Brushes.Red;
        public SolidColorBrush Msg2HttpFG
        {
            get
            {
                return _msg2HttpFG;
            }
            set
            {
                _msg2HttpFG = value;
                NotifyPropertyChanged("Msg2HttpFG");
            }
        }

        private string _msg2Jit = "";
        public string Msg2Jit
        {
            get
            {
                return _msg2Jit;
            }
            set
            {
                _msg2Jit = value;
                int count = 0;
                if (int.TryParse(_msg2Jit, out count) == false)
                    Msg2JitFG = Brushes.Red;
                else if (count != 0)
                    Msg2JitFG = Brushes.Red;
                else
                    Msg2JitFG = Brushes.Black;
                NotifyPropertyChanged("Msg2Jit");
            }
        }

        private SolidColorBrush _msg2JitFG = Brushes.Red;
        public SolidColorBrush Msg2JitFG
        {
            get
            {
                return _msg2JitFG;
            }
            set
            {
                _msg2JitFG = value;
                NotifyPropertyChanged("Msg2JitFG");
            }
        }

        private string _msg2Terminal = "";
        public string Msg2Terminal
        {
            get
            {
                return _msg2Terminal;
            }
            set
            {
                _msg2Terminal = value;
                int count = 0;
                if (int.TryParse(_msg2Terminal, out count) == false)
                    Msg2TerminalFG = Brushes.Red;
                else if (count != 0)
                    Msg2TerminalFG = Brushes.Red;
                else
                    Msg2TerminalFG = Brushes.Black;
                NotifyPropertyChanged("Msg2Terminal");
            }
        }

        private SolidColorBrush _msg2TerminalFG = Brushes.Red;
        public SolidColorBrush Msg2TerminalFG
        {
            get
            {
                return _msg2TerminalFG;
            }
            set
            {
                _msg2TerminalFG = value;
                NotifyPropertyChanged("Msg2TerminalFG");
            }
        }

        private string _oriDisplayLog = "";
        public string OriDisplayLog
        {
            get
            {
                return _oriDisplayLog;
            }
            set
            {
                string odl = value;
                if (string.IsNullOrWhiteSpace(odl))
                {
                    OriDisplayLogFG = Brushes.Red;
                    _oriDisplayLog = "";
                }
                else
                {
                    if (odl == "1" || string.Compare(odl, "true", true) == 0)
                    {
                        OriDisplayLogFG = Brushes.Black;
                        _oriDisplayLog = "ON";
                    }
                    else if (odl == "0" || string.Compare(odl, "false", true) == 0)
                    {
                        OriDisplayLogFG = Brushes.Black;
                        _oriDisplayLog = "OFF";
                    }
                    else
                    {
                        OriDisplayLogFG = Brushes.Red;
                        _oriDisplayLog = odl;
                    }
                }
                NotifyPropertyChanged("OriDisplayLog");
            }
        }

        private SolidColorBrush _oriDisplayLogFG = Brushes.Red;
        public SolidColorBrush OriDisplayLogFG
        {
            get
            {
                return _oriDisplayLogFG;
            }
            set
            {
                _oriDisplayLogFG = value;
                NotifyPropertyChanged("OriDisplayLogFG");
            }
        }

        private string _oriLogLevel = "";
        public string OriLogLevel
        {
            get
            {
                return _oriLogLevel;
            }
            set
            {
                string oll = value;
                if (string.IsNullOrWhiteSpace(oll))
                {
                    OriLogLevelFG = Brushes.Red;
                    _oriLogLevel = "";
                }
                else
                {
                    int ioll = 0;
                    if (int.TryParse(oll, out ioll) == false || ioll < 0 || ioll > 2)
                    {
                        OriLogLevelFG = Brushes.Red;
                        _oriLogLevel = oll;
                    }
                    else
                    {
                        OriLogLevelFG = Brushes.Black; ;
                        _oriLogLevel = _logType[ioll];
                    }
                }
                NotifyPropertyChanged("OriLogLevel");
            }
        }

        private SolidColorBrush _oriLogLevelFG = Brushes.Red;
        public SolidColorBrush OriLogLevelFG
        {
            get
            {
                return _oriLogLevelFG;
            }
            set
            {
                _oriLogLevelFG = value;
                NotifyPropertyChanged("OriLogLevelFG");
            }
        }

        private string _displayLog = "";
        public string DisplayLog
        {
            get
            {
                return _displayLog;
            }
            set
            {
                string dl = value;
                if (string.IsNullOrWhiteSpace(dl))
                {
                    DisplayLogFG = Brushes.Red;
                    _displayLog = "";
                }
                else
                {
                    if (dl == "1" || string.Compare(dl, "true", true) == 0)
                    {
                        DisplayLogFG = Brushes.Black;
                        _displayLog = "ON";
                    }
                    else if (dl == "0" || string.Compare(dl, "false", true) == 0)
                    {
                        DisplayLogFG = Brushes.Black;
                        _displayLog = "OFF";
                    }
                    else
                    {
                        DisplayLogFG = Brushes.Red;
                        _displayLog = dl;
                    }
                }
                NotifyPropertyChanged("DisplayLog");
            }
        }

        private SolidColorBrush _displayLogFG = Brushes.Red;
        public SolidColorBrush DisplayLogFG
        {
            get
            {
                return _displayLogFG;
            }
            set
            {
                _displayLogFG = value;
                NotifyPropertyChanged("DisplayLogFG");
            }
        }

        private string _logLevel = "";
        public string LogLevel
        {
            get
            {
                return _logLevel;
            }
            set
            {
                string ll = value;
                if (string.IsNullOrWhiteSpace(ll))
                {
                    LogLevelFG = Brushes.Red;
                    _logLevel = "";
                }
                else
                {
                    int ill = 0;
                    if (int.TryParse(ll, out ill) == false || ill < 0 || ill > 2)
                    {
                        LogLevelFG = Brushes.Red;
                        _logLevel = ll;
                    }
                    else
                    {
                        LogLevelFG = Brushes.Black;
                        _logLevel = _logType[ill];
                    }
                }
                NotifyPropertyChanged("LogLevel");
            }
        }

        private SolidColorBrush _logLevelFG = Brushes.Red;
        public SolidColorBrush LogLevelFG
        {
            get
            {
                return _logLevelFG;
            }
            set
            {
                _logLevelFG = value;
                NotifyPropertyChanged("LogLevelFG");
            }
        }

        private string _useMaster = "";
        public string UseMaster
        {
            get
            {
                return _useMaster;
            }
            set
            {
                string um = value;
                if (string.IsNullOrWhiteSpace(um))
                {
                    UseMasterFG = Brushes.Red;
                    _useMaster = "";
                }
                else
                {
                    if (um == "1" || string.Compare(um, "true", true) == 0)
                    {
                        UseMasterFG = Brushes.Black;
                        _useMaster = "ON";
                    }
                    else if (um == "0" || string.Compare(um, "false", true) == 0)
                    {
                        UseMasterFG = Brushes.Black;
                        _useMaster = "OFF";
                    }
                    else
                    {
                        UseMasterFG = Brushes.Red;
                        _useMaster = um;
                    }
                }
                NotifyPropertyChanged("UseMaster");
            }
        }

        private SolidColorBrush _useMasterFG = Brushes.Red;
        public SolidColorBrush UseMasterFG
        {
            get
            {
                return _useMasterFG;
            }
            set
            {
                _useMasterFG = value;
                NotifyPropertyChanged("UseMasterFG");
            }
        }

        private string _logCount = "";
        public string LogCount
        {
            get
            {
                return _logCount;
            }
            set
            {
                _logCount = value;
                int count = 0;
                if (int.TryParse(_logCount, out count) == false)
                    LogCountFG = Brushes.Red;
                else if (count < 0)
                    LogCountFG = Brushes.Red;
                else
                    LogCountFG = Brushes.Black;
                NotifyPropertyChanged("LogCount");
            }
        }

        private SolidColorBrush _logCountFG = Brushes.Red;
        public SolidColorBrush LogCountFG
        {
            get
            {
                return _logCountFG;
            }
            set
            {
                _logCountFG = value;
                NotifyPropertyChanged("LogCountFG");
            }
        }

        private string _masterContFail = "";
        public string MasterContFail
        {
            get
            {
                return _masterContFail;
            }
            set
            {
                _masterContFail = value;
                int count = 0;
                if (int.TryParse(_masterContFail, out count) == false)
                    MasterContFailFG = Brushes.Red;
                else if (count != 0)
                    MasterContFailFG = Brushes.Red;
                else
                    MasterContFailFG = Brushes.Black;
                NotifyPropertyChanged("MasterContFail");
            }
        }

        private SolidColorBrush _masterContFailFG = Brushes.Red;
        public SolidColorBrush MasterContFailFG
        {
            get
            {
                return _masterContFailFG;
            }
            set
            {
                _masterContFailFG = value;
                NotifyPropertyChanged("MasterContFailFG");
            }
        }

        private string _masterTotalFail = "";
        public string MasterTotalFail
        {
            get
            {
                return _masterTotalFail;
            }
            set
            {
                _masterTotalFail = value;
                int count = 0;
                if (int.TryParse(_masterTotalFail, out count) == false)
                    MasterTotalFailFG = Brushes.Red;
                else if (count != 0)
                    MasterTotalFailFG = Brushes.Red;
                else
                    MasterTotalFailFG = Brushes.Black;
                NotifyPropertyChanged("MasterTotalFail");
            }
        }

        private SolidColorBrush _masterTotalFailFG = Brushes.Red;
        public SolidColorBrush MasterTotalFailFG
        {
            get
            {
                return _masterTotalFailFG;
            }
            set
            {
                _masterTotalFailFG = value;
                NotifyPropertyChanged("MasterTotalFailFG");
            }
        }

        private string _bothContFail = "";
        public string BothContFail
        {
            get
            {
                return _bothContFail;
            }
            set
            {
                _bothContFail = value;
                int count = 0;
                if (int.TryParse(_bothContFail, out count) == false)
                    BothContFailFG = Brushes.Red;
                else if (count != 0)
                    BothContFailFG = Brushes.Red;
                else
                    BothContFailFG = Brushes.Black;
                NotifyPropertyChanged("BothContFail");
            }
        }

        private SolidColorBrush _bothContFailFG = Brushes.Red;
        public SolidColorBrush BothContFailFG
        {
            get
            {
                return _bothContFailFG;
            }
            set
            {
                _bothContFailFG = value;
                NotifyPropertyChanged("BothContFailFG");
            }
        }

        private string _bothTotalFail = "";
        public string BothTotalFail
        {
            get
            {
                return _bothTotalFail;
            }
            set
            {
                _bothTotalFail = value;
                int count = 0;
                if (int.TryParse(_bothTotalFail, out count) == false)
                    BothTotalFailFG = Brushes.Red;
                else if (count != 0)
                    BothTotalFailFG = Brushes.Red;
                else
                    BothTotalFailFG = Brushes.Black;
                NotifyPropertyChanged("BothTotalFail");
            }
        }

        private SolidColorBrush _bothTotalFailFG = Brushes.Red;
        public SolidColorBrush BothTotalFailFG
        {
            get
            {
                return _bothTotalFailFG;
            }
            set
            {
                _bothTotalFailFG = value;
                NotifyPropertyChanged("BothTotalFailFG");
            }
        }

        private string _jitServerActiveTime = "";
        public string JitServerActiveTime
        {
            get
            {
                return _jitServerActiveTime;
            }
            set
            {
                _jitServerActiveTime = value;
                DateTime dt;
                if (DateTime.TryParse(_jitServerActiveTime, out dt) == false)
                {
                    JitServerActiveTimeFG = Brushes.Red;
                    JitServerSleepTimeFG = Brushes.Red;
                }
                else
                {
                    JitServerSleepTimeSpan = DateTime.Now.Subtract(dt);
                    JitServerActiveTimeFG = Brushes.Black;
                }
                NotifyPropertyChanged("JitServerActiveTime");
            }
        }

        private SolidColorBrush _jitServerActiveTimeFG = Brushes.Red;
        public SolidColorBrush JitServerActiveTimeFG
        {
            get
            {
                return _jitServerActiveTimeFG;
            }
            set
            {
                _jitServerActiveTimeFG = value;
                NotifyPropertyChanged("JitServerActiveTimeFG");
            }
        }

        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterSleepTimeSpan
        /// </summary>
        private TimeSpan _jitServerSleepTimeSpan;
        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterSleepTimeSpan
        /// </summary>
        public TimeSpan JitServerSleepTimeSpan
        {
            get
            {
                return _jitServerSleepTimeSpan;
            }
            set
            {
                _jitServerSleepTimeSpan = value;
                JitServerSleepTime =
                    _jitServerSleepTimeSpan.Days.ToString() + " - " +
                    _jitServerSleepTimeSpan.Hours.ToString() + ":" +
                    _jitServerSleepTimeSpan.Minutes.ToString() + ":" +
                    _jitServerSleepTimeSpan.Seconds.ToString() + "." +
                    _jitServerSleepTimeSpan.Milliseconds.ToString();
                //if (_jitServerSleepTimeSpan.TotalMinutes >= DEF_HTTP_DISPATCHER_SLEEP_TIME)
                //    JitServerSleepTimeFG = Brushes.OrangeRed;
                //else if (_jitServerSleepTimeSpan.TotalMinutes >= 0.0)
                if (_jitServerSleepTimeSpan.TotalMinutes >= 0.0)
                    JitServerSleepTimeFG = Brushes.Black;
                else
                    JitServerSleepTimeFG = Brushes.Red;
                NotifyPropertyChanged("JitServerSleepTimeSpan");
            }
        }

        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterActiveTime
        /// </summary>
        private string _jitServerSleepTime = "";
        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterActiveTime
        /// </summary>
        public string JitServerSleepTime
        {
            get
            {
                return _jitServerSleepTime;
            }
            set
            {
                _jitServerSleepTime = value;
                NotifyPropertyChanged("JitServerSleepTime");
            }
        }

        private SolidColorBrush _jitServerSleepTimeFG = Brushes.Red;
        public SolidColorBrush JitServerSleepTimeFG
        {
            get
            {
                return _jitServerSleepTimeFG;
            }
            set
            {
                _jitServerSleepTimeFG = value;
                NotifyPropertyChanged("JitServerSleepTimeFG");
            }
        }

        private string _httpDispatcherActiveTime = "";
        public string HttpDispatcherActiveTime
        {
            get
            {
                return _httpDispatcherActiveTime;
            }
            set
            {
                _httpDispatcherActiveTime = value;
                DateTime dt;
                if (DateTime.TryParse(_httpDispatcherActiveTime, out dt) == false)
                {
                    HttpDispatcherActiveTimeFG = Brushes.Red;
                    HttpDispatcherSleepTimeFG = Brushes.Red;
                }
                else
                {
                    HttpDispatcherSleepTimeSpan = DateTime.Now.Subtract(dt);
                    HttpDispatcherActiveTimeFG = Brushes.Black;
                }
                NotifyPropertyChanged("HttpDispatcherActiveTime");
            }
        }

        private SolidColorBrush _httpDispatcherActiveTimeFG = Brushes.Red;
        public SolidColorBrush HttpDispatcherActiveTimeFG
        {
            get
            {
                return _httpDispatcherActiveTimeFG;
            }
            set
            {
                _httpDispatcherActiveTimeFG = value;
                NotifyPropertyChanged("HttpDispatcherActiveTimeFG");
            }
        }

        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterSleepTimeSpan
        /// </summary>
        private TimeSpan _httpDispatcherSleepTimeSpan;
        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterSleepTimeSpan
        /// </summary>
        public TimeSpan HttpDispatcherSleepTimeSpan
        {
            get
            {
                return _httpDispatcherSleepTimeSpan;
            }
            set
            {
                _httpDispatcherSleepTimeSpan = value;
                HttpDispatcherSleepTime =
                    _httpDispatcherSleepTimeSpan.Days.ToString() + " - " +
                    _httpDispatcherSleepTimeSpan.Hours.ToString() + ":" +
                    _httpDispatcherSleepTimeSpan.Minutes.ToString() + ":" +
                    _httpDispatcherSleepTimeSpan.Seconds.ToString() + "." +
                    _httpDispatcherSleepTimeSpan.Milliseconds.ToString();
                if (_httpDispatcherSleepTimeSpan.TotalMinutes >= DEF_HTTP_DISPATCHER_SLEEP_TIME)
                    HttpDispatcherSleepTimeFG = Brushes.OrangeRed;
                else if (_httpDispatcherSleepTimeSpan.TotalMinutes >= 0.0)
                    HttpDispatcherSleepTimeFG = Brushes.Black;
                else
                    HttpDispatcherSleepTimeFG = Brushes.Red;
                NotifyPropertyChanged("HttpDispatcherSleepTimeSpan");
            }
        }

        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterActiveTime
        /// </summary>
        private string _httpDispatcherSleepTime = "";
        /// <summary>
        /// Please do not do set operation and it should be done by setting HttpDispacterActiveTime
        /// </summary>
        public string HttpDispatcherSleepTime
        {
            get
            {
                return _httpDispatcherSleepTime;
            }
            set
            {
                _httpDispatcherSleepTime = value;
                NotifyPropertyChanged("HttpDispatcherSleepTime");
            }
        }

        private SolidColorBrush _httpDispatcherSleepTimeFG = Brushes.Red;
        public SolidColorBrush HttpDispatcherSleepTimeFG
        {
            get
            {
                return _httpDispatcherSleepTimeFG;
            }
            set
            {
                _httpDispatcherSleepTimeFG = value;
                NotifyPropertyChanged("HttpDispatcherSleepTimeFG");
            }
        }

        private string _httpMin = "";
        public string HttpMin
        {
            get
            {
                return _httpMin;
            }
            set
            {
                _httpMin = value;
                CheckHttpProcMinMax();
                NotifyPropertyChanged("HttpMin");
            }
        }

        private SolidColorBrush _httpMinFG = Brushes.Red;
        public SolidColorBrush HttpMinFG
        {
            get
            {
                return _httpMinFG;
            }
            set
            {
                _httpMinFG = value;
                NotifyPropertyChanged("HttpMinFG");
            }
        }

        private string _httpMax = "";
        public string HttpMax
        {
            get
            {
                return _httpMax;
            }
            set
            {
                _httpMax = value;
                CheckHttpProcMinMax();
                NotifyPropertyChanged("HttpMax");
            }
        }

        private SolidColorBrush _httpMaxFG = Brushes.Red;
        public SolidColorBrush HttpMaxFG
        {
            get
            {
                return _httpMaxFG;
            }
            set
            {
                _httpMaxFG = value;
                NotifyPropertyChanged("HttpMaxFG");
            }
        }

        //private string _httpWarning = "";
        //public string HttpWarning
        //{
        //    get
        //    {
        //        return _httpWarning;
        //    }
        //    set
        //    {
        //        _httpWarning = value;
        //        int count = 0;
        //        if (int.TryParse(_httpWarning, out count) == false)
        //            HttpWarningFG = Brushes.Red;
        //        else if (count <= 0)
        //            HttpWarningFG = Brushes.Red;
        //        else
        //            HttpWarningFG = Brushes.Black;
        //        NotifyPropertyChanged("HttpWarning");
        //    }
        //}

        //private SolidColorBrush _httpWarningFG = Brushes.Red;
        //public SolidColorBrush HttpWarningFG
        //{
        //    get
        //    {
        //        return _httpWarningFG;
        //    }
        //    set
        //    {
        //        _httpWarningFG = value;
        //        NotifyPropertyChanged("HttpWarningFG");
        //    }
        //}

        private string _httpIdle = "";
        public string HttpIdle
        {
            get
            {
                return _httpIdle;
            }
            set
            {
                _httpIdle = value;
                CheckHttpProcMinMax();
                NotifyPropertyChanged("HttpIdle");
            }
        }

        private SolidColorBrush _httpIdleFG = Brushes.Red;
        public SolidColorBrush HttpIdleFG
        {
            get
            {
                return _httpIdleFG;
            }
            set
            {
                _httpIdleFG = value;
                NotifyPropertyChanged("HttpIdleFG");
            }
        }

        private string _httpAvailable = "";
        public string HttpAvailable
        {
            get
            {
                return _httpAvailable;
            }
            set
            {
                _httpAvailable = value;
                CheckHttpProcMinMax();
                NotifyPropertyChanged("HttpAvailable");
            }
        }

        private SolidColorBrush _httpAvailableFG = Brushes.Red;
        public SolidColorBrush HttpAvailableFG
        {
            get
            {
                return _httpAvailableFG;
            }
            set
            {
                _httpAvailableFG = value;
                NotifyPropertyChanged("HttpAvailableFG");
            }
        }

        private string _accTermContFail = "";
        public string AccTermContFail
        {
            get
            {
                return _accTermContFail;
            }
            set
            {
                _accTermContFail = value;
                int count = 0;
                if (int.TryParse(_accTermContFail, out count) == false)
                    AccTermContFailFG = Brushes.Red;
                else if (count != 0)
                    AccTermContFailFG = Brushes.Red;
                else
                    AccTermContFailFG = Brushes.Black;
                NotifyPropertyChanged("AccTermContFail");
            }
        }

        private SolidColorBrush _accTermContFailFG = Brushes.Red;
        public SolidColorBrush AccTermContFailFG
        {
            get
            {
                return _accTermContFailFG;
            }
            set
            {
                _accTermContFailFG = value;
                NotifyPropertyChanged("AccTermContFailFG");
            }
        }

        private string _accTermTotalFail = "";
        public string AccTermTotalFail
        {
            get
            {
                return _accTermTotalFail;
            }
            set
            {
                _accTermTotalFail = value;
                int count = 0;
                if (int.TryParse(_accTermTotalFail, out count) == false)
                    AccTermTotalFailFG = Brushes.Red;
                else if (count != 0)
                    AccTermTotalFailFG = Brushes.Red;
                else
                    AccTermTotalFailFG = Brushes.Black;
                NotifyPropertyChanged("AccTermTotalFail");
            }
        }

        private SolidColorBrush _accTermTotalFailFG = Brushes.Red;
        public SolidColorBrush AccTermTotalFailFG
        {
            get
            {
                return _accTermTotalFailFG;
            }
            set
            {
                _accTermTotalFailFG = value;
                NotifyPropertyChanged("AccTermTotalFailFG");
            }
        }

        private string _accManTermContFail = "";
        public string AccManTermContFail
        {
            get
            {
                return _accManTermContFail;
            }
            set
            {
                _accManTermContFail = value;
                int count = 0;
                if (int.TryParse(_accManTermContFail, out count) == false)
                    AccManTermContFailFG = Brushes.Red;
                else if (count != 0)
                    AccManTermContFailFG = Brushes.Red;
                else
                    AccManTermContFailFG = Brushes.Black;
                NotifyPropertyChanged("AccManTermContFail");
            }
        }

        private SolidColorBrush _accManTermContFailFG = Brushes.Red;
        public SolidColorBrush AccManTermContFailFG
        {
            get
            {
                return _accManTermContFailFG;
            }
            set
            {
                _accManTermContFailFG = value;
                NotifyPropertyChanged("AccTermContFailFG");
            }
        }

        private string _accManTermTotalFail = "";
        public string AccManTermTotalFail
        {
            get
            {
                return _accManTermTotalFail;
            }
            set
            {
                _accManTermTotalFail = value;
                int count = 0;
                if (int.TryParse(_accManTermTotalFail, out count) == false)
                    AccManTermTotalFailFG = Brushes.Red;
                else if (count != 0)
                    AccManTermTotalFailFG = Brushes.Red;
                else
                    AccManTermTotalFailFG = Brushes.Black;
                NotifyPropertyChanged("AccManTermTotalFail");
            }
        }

        private SolidColorBrush _accManTermTotalFailFG = Brushes.Red;
        public SolidColorBrush AccManTermTotalFailFG
        {
            get
            {
                return _accManTermTotalFailFG;
            }
            set
            {
                _accManTermTotalFailFG = value;
                NotifyPropertyChanged("AccManTermTotalFailFG");
            }
        }

        private string _manTermCount = "";
        public string ManTermCount
        {
            get
            {
                return _manTermCount;
            }
            set
            {
                _manTermCount = value;
                int count = 0;
                if (int.TryParse(_manTermCount, out count) == false)
                    ManTermCountFG = Brushes.Red;
                else if (count < 0)
                    ManTermCountFG = Brushes.Red;
                else
                    ManTermCountFG = Brushes.Black;
                NotifyPropertyChanged("ManTermCount");
            }
        }

        private SolidColorBrush _manTermCountFG = Brushes.Red;
        public SolidColorBrush ManTermCountFG
        {
            get
            {
                return _manTermCountFG;
            }
            set
            {
                _manTermCountFG = value;
                NotifyPropertyChanged("ManTermCountFG");
            }
        }

        private string _termCount = "";
        public string TermCount
        {
            get
            {
                return _termCount;
            }
            set
            {
                _termCount = value;
                int count = 0;
                if (int.TryParse(_termCount, out count) == false)
                    TermCountFG = Brushes.Red;
                else if (count < 0)
                    TermCountFG = Brushes.Red;
                else
                    TermCountFG = Brushes.Black;
                NotifyPropertyChanged("TermCount");
            }
        }

        private SolidColorBrush _termCountFG = Brushes.Red;
        public SolidColorBrush TermCountFG
        {
            get
            {
                return _termCountFG;
            }
            set
            {
                _termCountFG = value;
                NotifyPropertyChanged("TermCountFG");
            }
        }

        private string _manTermFail = "";
        public string ManTermFail
        {
            get
            {
                return _manTermFail;
            }
            set
            {
                _manTermFail = value;
                int count = 0;
                if (int.TryParse(_manTermFail, out count) == false)
                    ManTermFailFG = Brushes.Red;
                else if (count != 0)
                    ManTermFailFG = Brushes.Red;
                else
                    ManTermFailFG = Brushes.Black;
                NotifyPropertyChanged("ManTermFail");
            }
        }

        private SolidColorBrush _manTermFailFG = Brushes.Red;
        public SolidColorBrush ManTermFailFG
        {
            get
            {
                return _manTermFailFG;
            }
            set
            {
                _manTermFailFG = value;
                NotifyPropertyChanged("ManTermFailFG");
            }
        }

        private string _termFail = "";
        public string TermFail
        {
            get
            {
                return _termFail;
            }
            set
            {
                _termFail = value;
                int count = 0;
                if (int.TryParse(_termFail, out count) == false)
                    TermFailFG = Brushes.Red;
                else if (count != 0)
                    TermFailFG = Brushes.Red;
                else
                    TermFailFG = Brushes.Black;
                NotifyPropertyChanged("TermFail");
            }
        }

        private SolidColorBrush _termFailFG = Brushes.Red;
        public SolidColorBrush TermFailFG
        {
            get
            {
                return _termFailFG;
            }
            set
            {
                _termFailFG = value;
                NotifyPropertyChanged("TermFailFG");
            }
        }

        #endregion

        public MainWindow()
        {
            InitializeComponent();

            DataContext = this;
            dgLog.DataContext = LogDisplayOc;
            LogDisplayOc.CollectionChanged += new NotifyCollectionChangedEventHandler(LogDisplayOc_CollectionChanged);
        }

        private void LogDisplayOc_CollectionChanged(object sender, NotifyCollectionChangedEventArgs e)
        {
            lock (_objLock)
            {
                if (LogIsAutoScrolling == false || LogDisplayOc.Count < 1 || ManagementTabSelected != 1)
                    return;

                Dispatcher.Invoke((ThreadStart)delegate()
                {
                    var border = VisualTreeHelper.GetChild(dgLog, 0) as Decorator;
                    if (border != null)
                    {
                        var scroll = border.Child as ScrollViewer;
                        if (scroll != null) scroll.ScrollToEnd();
                    }
                }, null);
            }
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            LoadConfig();

            AddMessage2Oc(msg: "Management monitor started.");
        }

        private void CheckHttpProcMinMax()
        {
            int min = 0;
            int max = 0;
            int idle = 0;
            int avai = 0;

            if (int.TryParse(HttpMin, out min) == false || int.TryParse(HttpMax, out max) == false ||
                int.TryParse(HttpIdle, out idle) == false || int.TryParse(HttpAvailable, out avai) == false)
            {
                HttpMinFG = Brushes.Red;
                HttpMaxFG = Brushes.Red;
                HttpIdleFG = Brushes.Red;
                HttpAvailableFG = Brushes.Red;
                return;
            }

            if (min <= 0 || max <= 0 || avai <= 0 || max <= min || max < avai || avai < idle)
            {
                HttpMinFG = Brushes.Red;
                HttpMaxFG = Brushes.Red;
                HttpIdleFG = Brushes.Red;
                HttpAvailableFG = Brushes.Red;
                return;
            }

            HttpMinFG = Brushes.Black;
            HttpMaxFG = Brushes.Black;

            if (avai < min)
                HttpAvailableFG = Brushes.Red;
            else if (avai < max)
                HttpAvailableFG = Brushes.OrangeRed;
            else
                HttpAvailableFG = Brushes.Black;

            if (idle < min)
                HttpIdleFG = Brushes.OrangeRed;
            else
                HttpIdleFG = Brushes.Black;
        }

        #region Window Exit

        private void Window_Exit(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Are you sure to quit \"Server Management\"?", "Comfirmation", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;

            _bInNormalClose = true;

            Close();
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            if (_bInNormalClose == false)
            {
                if (MessageBox.Show("Are you sure to quit \"Server Management\"?", "Comfirmation", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                    e.Cancel = true;
            }

            if (e.Cancel == false)
            {
                AddMessage2Oc(msg: "Application exits.");

                _manageCts.Cancel();
                try
                {
                    _manageTask.Wait(STOP_MANAGE_WAITING_TIME);
                }
                catch (AggregateException ae)
                {
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "End managment with error : " + ae.Message);
                    foreach (Exception ie in ae.InnerExceptions)
                    {
                        AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Inner error : " + ie.Message);
                    }
                }
                finally
                {
                }
                InRun = false;

                AddMessage2Oc(msg: "Saving log...");
                SaveLog();
                AddMessage2Oc(msg: "Log is saved completely.");
            }

            base.OnClosing(e);
        }

        #endregion

        private void AddMessage2Oc(
            LogItem.MessageFlowEnum msgFlow = LogItem.MessageFlowEnum.Self,
            LogItem.StatusEnum status = LogItem.StatusEnum.None,
            string msg = "")
        {
            Dispatcher.Invoke((ThreadStart)delegate()
            {
                LogItem li = new LogItem()
                     {
                         Index = (_logDispOc.Count > 0) ? (_logDispOc.Last().Index + 1) : 1,
                         TimeStamp = DateTime.Now,
                         MsgFlow = msgFlow,
                         Status = status,
                         Message = msg
                     };

                while (_logDispOc.Count >= _maxLogCountArray[MaxLogCountSelectedIndex])
                    _logDispOc.RemoveAt(0);

                _logDispOc.Add(li);

                if (CurrentSaveLogCount > 0 && _logOc.Count >= CurrentSaveLogCount)
                {
                    SaveLog();
                    _logOc.Clear();
                }

                if (CurrentSaveLogCount > 0)
                    _logOc.Add(li);
            }, null);
        }

        private void SaveLog()
        {
            string curLogFile = "";
            try
            {
                string[] fa = Directory.GetFiles(LogFolder, "ServerMonitor.*.log");
                int[] ca = new int[fa.Length];
                int index = 0;
                foreach (string fi in fa)
                {
                    try
                    {
                        string fn = fi.Substring(fi.LastIndexOf(@"\") + 1);
                        string[] fna = fn.Split(new string[] { "." }, StringSplitOptions.RemoveEmptyEntries);
                        int iv = int.Parse(fna[1]);
                        ca[index] = (iv > 0) ? iv : 0;
                    }
                    catch (Exception ex)
                    {
                        AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Ignore due to wrong file name format : " + fi);
                        AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: ex.Message);
                        ca[index] = 0;
                    }
                }
                int im = 0;
                foreach (int ci in ca)
                {
                    if (ci > im)
                        im = ci;
                }
                if (im == 0)
                    im = 1;
                curLogFile = LogFolder + @"\ServerMonitor." + im.ToString() + ".log";
                if (File.Exists(curLogFile) == true)
                {
                    FileInfo fit = new FileInfo(curLogFile);
                    if (fit.Length > 10 * 1024 * 1024)
                    {
                        im = im + 1;
                        curLogFile = LogFolder + @"\ServerMonitor." + im.ToString() + ".log";
                    }
                }
                StreamWriter sw = new StreamWriter(curLogFile, true);
                StringBuilder sb = new StringBuilder();
                foreach (LogItem li in _logOc)
                {
                    sb.Append(li.IndexString + "\t" + li.TimeStampString + "\t" + li.MsgFlow.ToString() + "\t" + li.Status.ToString() + "\t" + li.Message + "\r\n");
                }
                sw.WriteLine(sb.ToString());
                sw.Close();
                sw.Dispose();
            }
            catch (Exception ex)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Error in saving log file : " + curLogFile);
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: ex.Message);
            }
        }

        private void LoadConfig()
        {
            try
            {
                StreamReader sr = new StreamReader("serverconfig.txt");
                string strLine = null;
                int i = 0;
                while (true)
                {
                    strLine = sr.ReadLine();
                    if (string.IsNullOrWhiteSpace(strLine))
                        break;
                    if (i == 0)
                    {
                        ServerIP = strLine.Trim();
                        IPAddress ipad = null;
                        if (IPAddress.TryParse(ServerIP, out ipad) == false)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Server IP : " + ServerIP);
                            ServerIP = DEF_SERVER_IP;
                        }
                    }
                    else if (i == 1)
                    {
                        ServerPort = strLine.Trim();
                        int servPort = int.Parse(DEF_SERVER_PORT);
                        if (int.TryParse(ServerPort, out servPort) == false)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Server Port : " + ServerPort);
                            ServerPort = DEF_SERVER_PORT;
                        }
                        else if (servPort <= 0)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Server Port : " + ServerPort);
                            ServerPort = DEF_SERVER_PORT;
                        }
                    }
                    else if (i == 2)
                    {
                        string s = strLine.Trim();
                        int iv = DEF_AUTO_INTERVAL;
                        if (int.TryParse(s, out iv) == false)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Auto Interval : " + s);
                            iv = DEF_AUTO_INTERVAL;
                        }
                        else if (iv < 1)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Auto Interval : " + s);
                            iv = 1;
                        }
                        AutoInterval = iv;
                    }
                    else if (i == 3)
                    {
                        string s = strLine.Trim();
                        if (Directory.Exists(s) == false)
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Invalid Default Log Folder : " + s);
                        else
                            LogFolder = s;

                    }
                    else
                        break;

                    i++;
                }
                sr.Close();
                sr.Dispose();
            }
            catch (Exception ex)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Load configuration error : " + ex.Message);
                AddMessage2Oc(msg: "Using default values.");
                ServerIP = DEF_SERVER_IP;
                ServerPort = DEF_SERVER_PORT;
                AutoInterval = DEF_AUTO_INTERVAL;
                LogFolder = DEF_LOG_FOLDER;
                SaveConfig();
            }

            AddMessage2Oc(msg: "Server IP : " + ServerIP);
            AddMessage2Oc(msg: "Server Port : " + ServerPort);
            AddMessage2Oc(msg: "Auto Interval (s) : " + AutoInterval.ToString());
            AddMessage2Oc(msg: "Default Log Folder : " + LogFolder);
        }

        private void SaveConfig()
        {
            try
            {
                StreamWriter sw = new StreamWriter("serverconfig.txt");
                sw.WriteLine(ServerIP);
                sw.WriteLine(ServerPort);
                sw.WriteLine(AutoInterval.ToString());
                sw.WriteLine(LogFolder);
                sw.Close();
                sw.Dispose();
                AddMessage2Oc(msg: "Configuration is saved.");
            }
            catch (Exception ex)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Save configuration error : " + ex.Message);
            }
        }

        private void Start_Button_Click(object sender, RoutedEventArgs e)
        {
            InRun = true;
            ServerValid = true;
            _requestQueue.Clear();
            _manageCts = new CancellationTokenSource();
            _manageTask = Task.Factory.StartNew(
                () =>
                {
                    try
                    {
                        StartManageTimer(_manageCts.Token);
                        SocketTask(_manageCts.Token);
                    }
                    catch (Exception ex)
                    {
                        AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Management stops with error : " + ex.Message);
                    }
                    finally
                    {
                        try
                        {
                            if (_manageTimer != null)
                                _manageTimer.Dispose();
                        }
                        catch (Exception) { }
                        InRun = false;
                        ServerValid = false;
                    }
                }, _manageCts.Token);
        }

        private void Stop_Button_Click(object sender, RoutedEventArgs e)
        {
            _manageCts.Cancel();
            try
            {
                _manageTask.Wait(STOP_MANAGE_WAITING_TIME);
            }
            catch (AggregateException ae)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "End managment with error : " + ae.Message);
                foreach (Exception ie in ae.InnerExceptions)
                {
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Inner error : " + ie.Message);
                }
            }
            finally
            {
            }
            InRun = false;
        }

        private void SocketTask(CancellationToken ct)
        {
            _manageClient = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            IPAddress sip = IPAddress.Parse(ServerIP);
            int sp = int.Parse(ServerPort);
            IPEndPoint iep = new IPEndPoint(sip, sp);
            _manageClient.ReceiveTimeout = MT_TCP_RECEIVE_TIMEOUT;
            _manageClient.SendTimeout = MT_TCP_RECEIVE_TIMEOUT;
            _manageClient.Connect(iep);
            AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Connecting " + ServerIP + ":" + ServerPort);
            if (_manageClient.Connected)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Connected.");
                while (!ct.IsCancellationRequested)
                {
                    string req = GetRequest();
                    if (req != null)
                    {
                        AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Sending " + req);
                        _manageClient.Send(Encoding.ASCII.GetBytes(req));
                        AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Sent.");
                        int recLen = 0;
                        AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Receiving");
                        if ((recLen = _manageClient.Receive(_recBuffer)) == 0)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Nothing received.");
                        }
                        else
                        {
                            string rec = System.Text.Encoding.ASCII.GetString(_recBuffer, 0, recLen);
                            AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Received " + rec);
                            ProcessData(rec);
                        }
                    }
                    Thread.Sleep(100);
                }
                AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Disconnecting " + ServerIP + ":" + ServerPort);
                _manageClient.Disconnect(false);
                AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Disconnected.");
            }
            _manageClient.Close();
            AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Close connection.");
            _manageClient.Dispose();
            AddMessage2Oc(status: LogItem.StatusEnum.Info, msg: "Dispose connection.");
            _manageClient = null;
        }

        private void DisplayServerError()
        {
        }

        private void ProcessData(string msg)
        {
            if (string.IsNullOrWhiteSpace(msg))
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Empty message received.");
                DisplayServerError();
                return;
            }
            if (msg.Trim().Length < 6)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Error message received : " + msg);
                DisplayServerError();
                return;
            }

            string src = msg.Trim();
            string header = src.Substring(0, MSG_HEADER_LENGTH);
            string body = "";
            if (src.Length > MSG_HEADER_LENGTH)
                body = src.Substring(6);

            switch (header)
            {
                default:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Error message received : " + msg);
                    DisplayServerError();
                    break;
                case MT_QRY_ALL_STATES_OK:
                    #region
                    string[] sa = body.Split(new string[] { ";" }, StringSplitOptions.RemoveEmptyEntries);
                    foreach (string si in sa)
                    {
                        string sit = si.Trim();
                        int index = sit.IndexOf(":");
                        if (index < 1)
                        {
                            AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Error message content : " + sit);
                            DisplayServerError();
                        }
                        else
                        {
                            string sih = sit.Substring(0, index);
                            sih = sih.Trim();
                            string sib = "";
                            if (sit.Length <= index + 1)
                            {
                                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Error message content : " + sit);
                                DisplayServerError();
                            }
                            else
                            {
                                sib = sit.Substring(index + 1);
                                switch (sih)
                                {
                                    default:
                                        AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Unknown message content : " + sit);
                                        DisplayServerError();
                                        break;
                                    case "Msg2HttpCount":
                                        Msg2Http = sib;
                                        break;
                                    case "Msg2JitCount":
                                        Msg2Jit = sib;
                                        break;
                                    case "Msg2TermCount":
                                        Msg2Terminal = sib;
                                        break;
                                    case "DisplayLog":
                                        DisplayLog = sib;
                                        break;
                                    case "UseMaster":
                                        UseMaster = sib;
                                        break;
                                    case "MasterContFail":
                                        MasterContFail = sib;
                                        break;
                                    case "MasterTotalFail":
                                        MasterTotalFail = sib;
                                        break;
                                    case "JitContFail":
                                        BothContFail = sib;
                                        break;
                                    case "JitTotalFail":
                                        BothTotalFail = sib;
                                        break;
                                    case "HttpMin":
                                        HttpMin = sib;
                                        break;
                                    case "HttpMax":
                                        HttpMax = sib;
                                        break;
                                    case "HttpIdleCount":
                                        HttpIdle = sib;
                                        break;
                                    case "HttpAvailableCount":
                                        HttpAvailable = sib;
                                        break;
                                    case "AccTermCFC":
                                        AccTermContFail = sib;
                                        break;
                                    case "AccTermTFC":
                                        AccTermTotalFail = sib;
                                        break;
                                    case "AccMCFC":
                                        AccManTermContFail = sib;
                                        break;
                                    case "AccMTFC":
                                        AccManTermTotalFail = sib;
                                        break;
                                    case "LogLevel":
                                        LogLevel = sib;
                                        break;
                                    case "LogCount":
                                        LogCount = sib;
                                        break;
                                    //case "MTermCount":
                                    //	ManTermCount = sib;
                                    //	break;
                                    //case "TermCount":
                                    //	TermCount = sib;
                                    //	break;
                                    case "OriLogLevel":
                                        OriLogLevel = sib;
                                        break;
                                    case "OriDisplayLog":
                                        OriDisplayLog = sib;
                                        break;
                                    case "MTermInstCount":
                                        ManTermCount = sib;
                                        //ManTermInstCount = sib;
                                        break;
                                    case "TermInstCount":
                                        TermCount = sib;
                                        //TermInstCount = sib;
                                        break;
                                    case "HttpDispatcher":
                                        HttpDispatcherActiveTime = sib;
                                        break;
                                    case "LastJitTS":
                                        JitServerActiveTime = sib;
                                        break;
                                    case "ManTotalFail":
                                        ManTermFail = sib;
                                        break;
                                    case "TermTotalFail":
                                        TermFail = sib;
                                        break;
                                }
                            }
                        }
                    }
                    #endregion
                    break;
                case MT_QRY_ALL_STATES_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query all states fails.");
                    break;
                case MT_QRY_ALL_MT_OK:
                    ShowViewManTerm(body);
                    break;
                case MT_QRY_ALL_MT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query all management terminals fails.");
                    break;
                case MT_QRY_ALL_TERM_OK:
                    ShowViewManTerm(body, false);
                    break;
                case MT_QRY_ALL_TERM_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query all terminals fails.");
                    break;
                case MT_QRY_ALL_MT_COUNT_OK:
                    ManTermCount = body;
                    break;
                case MT_QRY_ALL_MT_COUNT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of all management terminals fails.");
                    break;
                case MT_QRY_ALL_TERM_COUNT_OK:
                    TermCount = body;
                    break;
                case MT_QRY_ALL_TERM_COUNT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of all terminals fails.");
                    break;
                case MT_QRY_USE_MASTER_STATE_OK:
                    UseMaster = body;
                    break;
                case MT_QRY_USE_MASTER_STATE_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query in-use JIT server fails.");
                    break;
                case MT_QRY_ORI_DISPLAY_LOG_STATE_OK:
                    OriDisplayLog = body;
                    break;
                case MT_QRY_ORI_DISPLAY_LOG_STATE_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query original display log state fails.");
                    break;
                case MT_QRY_ORI_LOG_LEVEL_OK:
                    OriLogLevel = body;
                    break;
                case MT_QRY_ORI_LOG_LEVEL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query original log level fails.");
                    break;
                case MT_QRY_DISPLAY_LOG_STATE_OK:
                    DisplayLog = body;
                    break;
                case MT_QRY_DISPLAY_LOG_STATE_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query display log state fails.");
                    break;
                case MT_QRY_LOG_LEVEL_OK:
                    LogLevel = body;
                    break;
                case MT_QRY_LOG_LEVEL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query log level fails.");
                    break;
                case MT_QRY_ALL_LOG_COUNT_OK:
                    LogCount = body;
                    break;
                case MT_QRY_ALL_LOG_COUNT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query log count fails.");
                    break;
                case MT_QRY_ALL_2HTTP_COUNT_OK:
                    Msg2Http = body;
                    break;
                case MT_QRY_ALL_2HTTP_COUNT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of stored to-http messages fails.");
                    break;
                case MT_QRY_ALL_2JIT_COUNT_OK:
                    Msg2Jit = body;
                    break;
                case MT_QRY_ALL_2JIT_COUNT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of stored to-jit messages fails.");
                    break;
                case MT_QRY_ALL_2TERM_COUNT_OK:
                    Msg2Terminal = body;
                    break;
                case MT_QRY_ALL_2TERM_COUNT_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of stored to-term messages fails.");
                    break;
                case MT_QRY_MASTER_JIT_CONT_FAIL_OK:
                    MasterContFail = body;
                    break;
                case MT_QRY_MASTER_JIT_CONT_FAIL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of master jit continous failures fails.");
                   break;
                case MT_QRY_MASTER_JIT_TOTAL_FAIL_OK:
                   MasterTotalFail = body;
                   break;
                case MT_QRY_MASTER_JIT_TOTAL_FAIL_ERR:
                     AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of master jit total failures fails.");
                  break;
                case MT_QRY_BOTH_JIT_CONT_FAIL_OK:
                  BothContFail = body;
                  break;
                case MT_QRY_BOTH_JIT_CONT_FAIL_ERR:
                  AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of both jit continous failures fails.");
                  break;
                case MT_QRY_BOTH_JIT_TOTAL_FAIL_OK:
                  BothTotalFail = body;
                  break;
                case MT_QRY_BOTH_JIT_TOTAL_FAIL_ERR:
                  AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of both jit total failures fails.");
                  break;
                case MT_QRY_ACC_TERM_CONT_FAIL_OK:
                    AccTermContFail = body;
                    break;
                case MT_QRY_ACC_TERM_CONT_FAIL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of continous accepting term fails.");
                    break;
                case MT_QRY_ACC_TERM_TOTAL_FAIL_OK:
                    AccTermTotalFail = body;
                    break;
                case MT_QRY_ACC_TERM_TOTAL_FAIL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of total accepting term fails.");
                    break;
                case MT_QRY_ACC_MT_CONT_FAIL_OK:
                    AccManTermContFail = body;
                    break;
                case MT_QRY_ACC_MT_CONT_FAIL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of continous accepting man term fails.");
                    break;
                case MT_QRY_ACC_MT_TOTAL_FAIL_OK:
                    AccManTermTotalFail = body;
                    break;
                case MT_QRY_ACC_MT_TOTAL_FAIL_ERR:
                    AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Query count of total accepting man term fails.");
                    break;
            }
        }

        private void ShowViewManTerm(string body, bool isManTerm = true)
        {
            Task.Factory.StartNew(
                () =>
                {
                    Dispatcher.Invoke((ThreadStart)delegate()
                    {
                        ViewManTerm vmt = new ViewManTerm(body, isManTerm);
                        vmt.ShowDialog();
                    }, null);
                }
            );
        }

        private string GetRequest()
        {
            lock (_objReqLock)
            {
                if (_requestQueue.Count > 0)
                    return _requestQueue.Dequeue();
                else
                    return null;
            }
        }

        private void PutRequest(string s)
        {
            lock (_objReqLock)
            {
                _requestQueue.Enqueue(s);
            }
        }

        private void StartManageTimer(CancellationToken ct)
        {
            _manageTimer = new Timer(new TimerCallback(ManageTimerCallback), ct, 0, AutoInterval * 1000);
        }

        private void ManageTimerCallback(object state)
        {
            lock (_objReqLock)
            {
                if (_manageTimer == null)
                    return;

                CancellationToken ct = (CancellationToken)state;
                if (!ct.IsCancellationRequested)
                    PutRequest(MT_QRY_ALL_STATES);
            }
        }

        private void Computer_Button_Click(object sender, RoutedEventArgs e)
        {
            ServerConfig sc = new ServerConfig(ServerIP, ServerPort, AutoInterval.ToString());
            if (sc.ShowDialog() == false)
                return;
            bool needSave = false;
            if (ServerIP != sc.ServerIP)
            {
                needSave = true;
                ServerIP = sc.ServerIP;
            }
            if (ServerPort != sc.ServerPort)
            {
                needSave = true;
                ServerPort = sc.ServerPort;
            }
            if (AutoInterval != sc.AutoIntervalNumber)
            {
                needSave = true;
                AutoInterval = sc.AutoIntervalNumber;
            }

            if (needSave == true)
            {
                AddMessage2Oc(msg: "Server IP : " + ServerIP);
                AddMessage2Oc(msg: "Server Port : " + ServerPort);
                AddMessage2Oc(msg: "Auto Interval (s) : " + AutoInterval.ToString());
                SaveConfig();
            }
        }

        private void Clear_Button_Click(object sender, RoutedEventArgs e)
        {
            lock (_objLock)
            {
                _logDispOc.Clear();
            }
        }

        private void RefreshMsg2Http_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_2HTTP_COUNT);
        }

        private void SetMsg2Http_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshMsg2Jit_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_2JIT_COUNT);
        }

        private void SetMsg2Jit_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshMsg2Terminal_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_2TERM_COUNT);
        }

        private void SetMsg2Terminal_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearMsg2Terminal_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveMsg2Terminal_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearMsg2Jit_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveMsg2Jit_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearMsg2Http_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveMsg2Http_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshDisplayLog_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_DISPLAY_LOG_STATE);
        }

        private void SetDisplayLog_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshLogLevel_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_LOG_LEVEL);
        }

        private void SetLogLevel_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshUseMaster_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_USE_MASTER_STATE);
        }

        private void SetUseMaster_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshOriLogLevel_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ORI_LOG_LEVEL);
        }

        private void RefreshOriDisplayLog_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ORI_DISPLAY_LOG_STATE);
        }

        private void RefreshHttpIdle_Button_click(object sender, RoutedEventArgs e)
        {
        }

        private void RefreshHttpAvailable_Button_click(object sender, RoutedEventArgs e)
        {
        }

        private void RefreshAccTermContFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ACC_TERM_CONT_FAIL);
        }

        private void ClearAccTermContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshAccTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ACC_TERM_TOTAL_FAIL);
        }

        private void ClearAccTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshAccManTermContFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ACC_MT_CONT_FAIL);
        }

        private void ClearAccManTermContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshAccManTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ACC_MT_TOTAL_FAIL);
        }

        private void ClearAccManTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshLogCount_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_LOG_COUNT);
        }

        private void QueryLogCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshManTermCount_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_MT_COUNT);
        }

        private void RefreshTermCount_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_TERM_COUNT);
        }

        private void ClearLogCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveLogCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryTermCount_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_TERM);
        }

        private void QueryMsg2Terminal_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryMsg2Jit_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryMsg2Http_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryManTermCount_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_ALL_MT);
        }

        private void QueryMasterJitFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveMasterJitFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryBothJitFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveBothJitFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveManTermCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearManTermCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveTermCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearTermCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryAccTermContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveAccTermContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryAccTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveAccTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryAccManTermContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveAccManTermContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryAccManTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveAccManTermTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SetHttpAvailableWarning_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SetHttpIdleWarning_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshHttpMinCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SetHttpMinCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshHttpMaxCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SetHttpMaxCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshHttpWarningCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SetHttpWarningCount_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SetLogFolder_Button_Click(object sender, RoutedEventArgs e)
        {
        }

        private void OpenLogFolder_Button_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                System.Diagnostics.Process.Start(LogFolder);
            }
            catch (Exception ex)
            {
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: "Cannot open log folder : " + LogFolder);
                AddMessage2Oc(status: LogItem.StatusEnum.Error, msg: ex.Message);
            }
        }

        private void RefreshHttpDispatcherActiveTime_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshHttpDispatcherSleepTime_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshBothContFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_BOTH_JIT_CONT_FAIL);
        }

        private void QueryBothContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveBothContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearBothContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshBothTotalFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_BOTH_JIT_TOTAL_FAIL);
        }

        private void QueryBothTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveBothTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearBothTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshMasterContFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_MASTER_JIT_CONT_FAIL);
        }

        private void QueryMasterContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveMasterContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshMasterTotalFail_Button_click(object sender, RoutedEventArgs e)
        {
            PutRequest(MT_QRY_MASTER_JIT_TOTAL_FAIL);
        }

        private void QueryMasterTotaltFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveMasterTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearMasterTotalFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearMasterContFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshManTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryManTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveManTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearManTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void RefreshTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void QueryTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void SaveTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }

        private void ClearTermFail_Button_click(object sender, RoutedEventArgs e)
        {

        }
    }

    public class INotifyPropertyChangedClass : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler PropertyChanged;
        public void NotifyPropertyChanged(string propertyName)
        {
            if (PropertyChanged != null)
                PropertyChanged(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public class LogItem : INotifyPropertyChangedClass
    {
        public enum MessageFlowEnum
        {
            ToServer,
            FromServer,
            Self
        }

        public enum StatusEnum
        {
            None,
            Info,
            Ok,
            Ques,
            Error
        }

        private int _index = 1;
        public int Index
        {
            get
            {
                return _index;
            }
            set
            {
                _index = value;
                NotifyPropertyChanged("Index");
                NotifyPropertyChanged("IndexString");
            }
        }

        public string IndexString
        {
            get
            {
                return _index.ToString();
            }
        }

        private DateTime _timeStamp = DateTime.Now;
        public DateTime TimeStamp
        {
            get
            {
                return _timeStamp;
            }
            set
            {
                _timeStamp = value;
                NotifyPropertyChanged("TimeStamp");
                NotifyPropertyChanged("TimeStampString");
            }
        }

        public string TimeStampString
        {
            get
            {
                return _timeStamp.ToLongDateString() + " " + _timeStamp.ToLongTimeString();
            }
        }

        private MessageFlowEnum _msgFlow = MessageFlowEnum.Self;
        public MessageFlowEnum MsgFlow
        {
            get
            {
                return _msgFlow;
            }
            set
            {
                _msgFlow = value;
                NotifyPropertyChanged("MsgFlow");
                if (_msgFlow == MessageFlowEnum.Self)
                {
                    MsgFlowImage = null;
                }
                else
                {
                    MsgFlowImage = new BitmapImage();
                    MsgFlowImage.BeginInit();
                    if (_msgFlow == MessageFlowEnum.ToServer)
                        MsgFlowImage.UriSource = new Uri("pack://application:,,,/TcpHttpManagement;component/resources/ToServer.png");
                    else
                        MsgFlowImage.UriSource = new Uri("pack://application:,,,/TcpHttpManagement;component/resources/FromServer.png");
                    MsgFlowImage.EndInit();
                }
                NotifyPropertyChanged("MsgFlowImage");
            }
        }

        private BitmapImage _msgFlowImage = null;
        public BitmapImage MsgFlowImage
        {
            get
            {
                return _msgFlowImage;
            }
            set
            {
                _msgFlowImage = value;
                NotifyPropertyChanged("MsgFlowImage");
            }
        }

        private StatusEnum _status = StatusEnum.None;
        public StatusEnum Status
        {
            get
            {
                return _status;
            }
            set
            {
                _status = value;
                NotifyPropertyChanged("Status");
                if (_status == StatusEnum.None)
                {
                    StatusImage = null;
                }
                else
                {
                    StatusImage = new BitmapImage();
                    StatusImage.BeginInit();
                    if (_status == StatusEnum.Info)
                        StatusImage.UriSource = new Uri("pack://application:,,,/TcpHttpManagement;component/resources/status_info.png");
                    else if (_status == StatusEnum.Ok)
                        StatusImage.UriSource = new Uri("pack://application:,,,/TcpHttpManagement;component/resources/status_ok.png");
                    else if (_status == StatusEnum.Ques)
                        StatusImage.UriSource = new Uri("pack://application:,,,/TcpHttpManagement;component/resources/status_ques.png");
                    else
                        StatusImage.UriSource = new Uri("pack://application:,,,/TcpHttpManagement;component/resources/status_error.png");
                    StatusImage.EndInit();
                }
                NotifyPropertyChanged("StatusImage");
            }
        }

        private BitmapImage _statusImage = null;
        public BitmapImage StatusImage
        {
            get
            {
                return _statusImage;
            }
            set
            {
                _statusImage = value;
                NotifyPropertyChanged("StatusImage");
            }
        }

        private string _message = "";
        public string Message
        {
            get
            {
                return _message;
            }
            set
            {
                _message = value;
                NotifyPropertyChanged("Message");
            }
        }
    }
}
