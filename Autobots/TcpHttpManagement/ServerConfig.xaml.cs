using System;
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
    /// Interaction logic for ServerConfig.xaml
    /// </summary>
    public partial class ServerConfig : Window, INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler PropertyChanged;
        public void NotifyPropertyChanged(string propertyName)
        {
            if (PropertyChanged != null)
                PropertyChanged(this, new PropertyChangedEventArgs(propertyName));
        }

        private const string DEF_AUTO_INTERVAL = "30";
        private const string DEF_SERVER_IP = "127.0.0.1";
        private const string DEF_SERVER_PORT = "5081";

        private string _serverIP = DEF_SERVER_IP;
        public string ServerIP
        {
            get
            {
                return _serverIP.Trim();
            }
            set
            {
                _serverIP = value;
                IPAddress ipad = null;
                if (IPAddress.TryParse(_serverIP, out ipad) == false)
                    ServerIPValid = false;
                else
                    ServerIPValid = true;
                NotifyPropertyChanged("ServerIP");
            }
        }

        private bool _serverIPValid = false;
        public bool ServerIPValid
        {
            get
            {
                return _serverIPValid;
            }
            set
            {
                _serverIPValid = value;
                NotifyPropertyChanged("ServerIPValid");
                NotifyPropertyChanged("DataValid");
            }
        }

        private string _serverPort = DEF_SERVER_PORT;
        public string ServerPort
        {
            get
            {
                return _serverPort.Trim();
            }
            set
            {
                _serverPort = value;
                int serverPort = int.Parse(DEF_SERVER_PORT);
                if (int.TryParse(_serverPort, out serverPort) == false)
                {
                    ServerPortValid = false;
                    ServerPortFG = Brushes.Red;
                }
                else if (serverPort <= 0)
                {
                    ServerPortValid = false;
                    ServerPortFG = Brushes.Red;
                }
                else
                {
                    ServerPortValid = true;
                    ServerPortFG = Brushes.Black;
                }
                NotifyPropertyChanged("ServerPort");
            }
        }

        private bool _serverPortValid = false;
        public bool ServerPortValid
        {
            get
            {
                return _serverPortValid;
            }
            set
            {
                _serverPortValid = value;
                NotifyPropertyChanged("ServerPortValid");
                NotifyPropertyChanged("DataValid");
            }
        }

        private SolidColorBrush _serverPortFG = Brushes.Black;
        public SolidColorBrush ServerPortFG
        {
            get
            {
                return _serverPortFG;
            }
            set
            {
                _serverPortFG = value;
                NotifyPropertyChanged("ServerPortFG");
            }
        }

        private string _autoInterval = DEF_AUTO_INTERVAL;
        public string AutoInterval
        {
            get
            {
                return _autoInterval.Trim();
            }
            set
            {
                _autoInterval = value;
                int autoInterval = int.Parse(DEF_AUTO_INTERVAL);
                if (int.TryParse(_autoInterval, out autoInterval) == false)
                {
                    AutoIntervalValid = false;
                    AutoIntervalFG = Brushes.Red;
                }
                else if (autoInterval < 1)
                {
                    AutoIntervalValid = false;
                    AutoIntervalFG = Brushes.Red;
                }
                else
                {
                    AutoIntervalValid = true; 
                    AutoIntervalFG = Brushes.Black;
                }
                NotifyPropertyChanged("AutoInterval");
            }
        }

        public int AutoIntervalNumber
        {
            get
            {
                return int.Parse(AutoInterval);
            }
        }

        private bool _autoIntervalValid = false;
        public bool AutoIntervalValid
        {
            get
            {
                return _autoIntervalValid;
            }
            set
            {
                _autoIntervalValid = value;
                NotifyPropertyChanged("AutoIntervalValid");
                NotifyPropertyChanged("DataValid");
            }
        }

        private SolidColorBrush _autoIntervalFG = Brushes.Black;
        public SolidColorBrush AutoIntervalFG
        {
            get
            {
                return _autoIntervalFG;
            }
            set
            {
                _autoIntervalFG = value;
                NotifyPropertyChanged("AutoIntervalFG");
            }
        }

        public bool DataValid
        {
            get
            {
                return ServerIPValid && ServerPortValid && AutoIntervalValid;
            }
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="sip">Server IP</param>
        /// <param name="sp">Server Port</param>
        /// <param name="ai">Auto Interval</param>
        public ServerConfig(string sip = DEF_SERVER_IP, string sp = DEF_SERVER_PORT, string ai = DEF_AUTO_INTERVAL)
        {
            InitializeComponent();

            DataContext = this;

            ServerIP = sip;
            ServerPort = sp;
            AutoInterval = ai;
        }

        private void OK_Button_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = true;
        }

        private void Cancel_Button_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
        }
    }
}
