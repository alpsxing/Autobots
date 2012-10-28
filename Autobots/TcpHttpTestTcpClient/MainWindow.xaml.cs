using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
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

namespace TcpHttpTestTcpClient
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

		private bool _receivingData = true;

		private string _serverIPAddress = "127.0.0.1";
		public string ServerIPAddress
		{
			get
			{
				return _serverIPAddress;
			}
			set
			{
				_serverIPAddress = value;
				NotifyPropertyChanged("ServerIPAddress");
			}
		}

        private string _serverPort = "5080";
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
            }
        }

        private string _serverRepeat = "1";
        public string ServerRepeat
        {
            get
            {
                int i = 1;
                if (int.TryParse(_serverRepeat, out i) == false || i < 1)
                    _serverRepeat = "1";
                return _serverRepeat;
            }
            set
            {
                int i = 1;
                _serverRepeat = value;
                if (int.TryParse(_serverRepeat, out i) == false || i < 1)
                    _serverRepeat = "1";
                NotifyPropertyChanged("ServerRepeat");
            }
        }

        private string _serverRequest = "1";
        public string ServerRequest
        {
            get
            {
                int i = 1;
                if (int.TryParse(_serverRequest, out i) == false || i < 1)
                    _serverRequest = "1";
                return _serverRequest;
            }
            set
            {
                int i = 1;
                _serverRequest = value;
                if (int.TryParse(_serverRequest, out i) == false || i < 1)
                    _serverRequest = "1";
                NotifyPropertyChanged("ServerRequest");
            }
        }

		private string _msgInterval = "60";
		public string MsgInterval
		{
			get
			{
				int i = 1;
				if (int.TryParse(_msgInterval, out i) == false || i < 1)
					_msgInterval = "5";
				return _msgInterval;
			}
			set
			{
				int i = 1;
				_msgInterval = value;
				if (int.TryParse(_msgInterval, out i) == false || i < 1)
					_msgInterval = "5";
				NotifyPropertyChanged("MsgInterval");
			}
		}

		public int MsgIntervalMs
		{
			get
			{
				int i = 5;
				if (int.TryParse(MsgInterval, out i) == false || i < 1)
				{
					i = 5000;
					MsgInterval = "5";
				}
				else
					i = i * 1000;

				return i;
			}
		}

		private string _textForSend = "";
		public string TextForSend
		{
			get
			{
				return _textForSend;
			}
			set
			{
				_textForSend = value;
				NotifyPropertyChanged("TextForSend");
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
			}
		}

		public bool NotInRun
		{
			get
			{
				return !_inRun;
			}
		}

		private ObservableCollection<SentReceivedItem> _sentReceivedOc = new ObservableCollection<SentReceivedItem>();
		public ObservableCollection<SentReceivedItem> SentReceivedOc
		{
			get
			{
				return _sentReceivedOc;
			}
		}

        private object _objLock = new object();
        public object ObjLock
        {
            get
            {
                return _objLock;
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

		private int _passCount = 0;
		public int PassCount
		{
			get
			{
				return _passCount;
			}
			set
			{
				_passCount = value;
				NotifyPropertyChanged("PassCount");
				PassInformation = "Pass : " + PassCount.ToString();
			}
		}

		private string _passInfo = "Pass : 0";
		public string PassInformation
		{
			get
			{
				return _passInfo;
			}
			set
			{
				_passInfo = value;
				NotifyPropertyChanged("PassInformation");
			}
		}

		private int _failCount = 0;
		public int FailCount
		{
			get
			{
				return _failCount;
			}
			set
			{
				_failCount = value;
				NotifyPropertyChanged("FailCount");
				FailInformation = "Failures : " + FailCount.ToString();
			}
		}

		private string _failInfo = "Failures : 0";
		public string FailInformation
		{
			get
			{
				return _failInfo;
			}
			set
			{
				_failInfo = value;
				NotifyPropertyChanged("FailInformation");
			}
		}

		public MainWindow()
		{
			InitializeComponent();

			DataContext = this;
			dgSentReceived.DataContext = SentReceivedOc;
            SentReceivedOc.CollectionChanged += new NotifyCollectionChangedEventHandler(SentReceivedOc_CollectionChanged);
        }

        private void SentReceivedOc_CollectionChanged(object sender, NotifyCollectionChangedEventArgs e)
        {
			lock (_objLock)
			{
				if (LogIsAutoScrolling == false || SentReceivedOc.Count < 1)
					return;
				
				if (SentReceivedOc.Count < 1)
                    return;
                var border = VisualTreeHelper.GetChild(dgSentReceived, 0) as Decorator;
                if (border != null)
                {
                    var scroll = border.Child as ScrollViewer;
                    if (scroll != null) scroll.ScrollToEnd();
                }
            }
        }

        private void Send_ButtonClick(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(TextForSend))
            {
                PostLog("Cannot send empty data...");
                return;
            }

            InRun = true;
			PassCount = 0;
			FailCount = 0;
            if (ServerRequest != "1")
            {
                Thread th = new Thread(new ThreadStart(ClientThreadTask));
                th.Start();
            }
            else
            {
                Thread th = new Thread(new ThreadStart(ClientThread));
                th.Start();
            }
        }

        private void ClientThread()
        {
            DoClientThread();
        }

        private void ClientThreadTask()
        {
            Task[] ts = new Task[int.Parse(ServerRequest)];
            int index = 0;
            for (int i = 0; i < ts.Length; i++)
            {
                ts[i] = Task.Factory.StartNew(
                    () =>
                    {
                        DoClientThread(index++);
                    });
            }
            Task.WaitAll(ts);
            InRun = false;
        }

        private void DoClientThread(int indexThread = -1)
        {
            int count = int.Parse(ServerRepeat);
            string receivedText = "";
            Socket client = null;
            string indexThreadDisplay = "";
            if (indexThread != -1)
                indexThreadDisplay = "Thread " + indexThread.ToString() + " : ";
            try
            {
                client = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
                IPAddress local = IPAddress.Parse(ServerIPAddress);
				int port = 5080;
				if(int.TryParse(ServerPort,out port) == false)
					port = 5080;
				IPEndPoint iep = new IPEndPoint(local, port);
                client.ReceiveTimeout = 60000;
                if (count == 1)
                    PostLog(indexThreadDisplay + "Trying to connect...");
                else
                    PostLog(indexThreadDisplay + count.ToString() + " : Trying to connect...");
                client.Connect(iep);
                if (client.Connected)
                {
					for (int index = 0; index < count; index++)
					{
						if (count == 1)
						{
							PostLog(indexThreadDisplay + "Connected.");
							PostLog(indexThreadDisplay + "Trying to send \"" + TextForSend + "\"...");
						}
						else
						{
							PostLog(indexThreadDisplay + count.ToString() + " : " + index.ToString() + " : Connected.");
							PostLog(indexThreadDisplay + count.ToString() + " : " + index.ToString() + " : Trying to send \"" + TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString() + "\"...");
						}
						client.Send(Encoding.ASCII.GetBytes(TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString()));
						if (count == 1)
							PostLog(indexThreadDisplay + "Sent.");
						else
							PostLog(indexThreadDisplay + count.ToString() + " : " + index.ToString() + " : Sent.");
						if (_receivingData == true)
						{
							byte[] bytes = new byte[1024 * 16];
							int length = 0;
							if (count == 1)
								PostLog(indexThreadDisplay + "Trying to receive ...");
							else
								PostLog(indexThreadDisplay + count.ToString() + " : " + index.ToString() + " : Trying to receive ...");
							if ((length = client.Receive(bytes)) == 0)
							{
								if (count == 1)
									PostLog(indexThreadDisplay + "Haven't received any data.");
								else
									PostLog(indexThreadDisplay + count.ToString() + " : " + index.ToString() + " : Haven't received any data.");
							}
							else
							{
								receivedText = System.Text.Encoding.ASCII.GetString(bytes, 0, length);
								if (count == 1)
									PostLog(indexThreadDisplay + "Received \"" + receivedText + "\".", Brushes.Blue);
								else
									PostLog(indexThreadDisplay + count.ToString() + " : " + index.ToString() + " : Received \"" + receivedText + "\".", Brushes.Blue);
							}
						}
						bool isCorrectData = false;
						if (receivedText.EndsWith(TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString()))
						{
							isCorrectData = true;
							PassCount++;
						}
						else
							FailCount++;
						//if (indexThread == -1)
						//{
						//    Dispatcher.Invoke((ThreadStart)delegate()
						//    {
						//        SentReceivedOc.Add(new SentReceivedItem()
						//        {
						//            Index = SentReceivedOc.Count.ToString(),
						//            Sent = TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString(),
						//            Received = receivedText,
						//            DataCorrect = (isCorrectData) ? SentReceivedItem.DataCorrectEnum.Ok : SentReceivedItem.DataCorrectEnum.Error
						//        });
						//    }, null);
						//}
						//else
						{
							Dispatcher.Invoke((ThreadStart)delegate()
							{
								SentReceivedOc.Add(new SentReceivedItem()
								{
									Index = SentReceivedOc.Count.ToString(),
									Sent = TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString(),
									Received = receivedText,
									DataCorrect = (isCorrectData) ? SentReceivedItem.DataCorrectEnum.Ok : SentReceivedItem.DataCorrectEnum.Error
								});
							}, null);
						}
						if (ServerRepeat != "1")
						{
							PostLog((indexThreadDisplay + " Sleep " + MsgIntervalMs + "ms").Trim());
							Thread.Sleep(MsgIntervalMs);
						}
					}
					PostLog(indexThreadDisplay + "Trying to disconnecting ...");
					client.Disconnect(false);
					PostLog(indexThreadDisplay + "Disconnected.");
				}
				PostLog(indexThreadDisplay + "Trying to closing ...");
				client.Close();
				PostLog(indexThreadDisplay + "Closed.");
				PostLog(indexThreadDisplay + "Trying to disposing ...");
				client.Dispose();
				PostLog(indexThreadDisplay + "Disposed.");
			}
            catch (Exception ex)
            {
                if (count == 1)
                    PostLog(indexThreadDisplay + "Session error : " + ex.Message);
                else
                    PostLog(indexThreadDisplay + count.ToString() + " : Session error : " + ex.Message);
                if (client != null)
                {
                    try
                    {
                        client.Disconnect(false);
                    }
                    catch (Exception) { }
                    try
                    {
                        client.Close();
                    }
                    catch (Exception) { }
                    try
                    {
                        client.Dispose();
                    }
                    catch (Exception) { }
                }
            }
            if (count == 1)
                PostLog(indexThreadDisplay + "Session finished.");
            else
                PostLog(indexThreadDisplay + count.ToString() + " : Session finished.");
            if(indexThread == -1)
                InRun = false;
        }

		private void PostLog(string msg)
		{
			PostLog(msg, Brushes.Black);
		}

        private void PostLog(string msg, SolidColorBrush scb)
		{
			lock(_objLock)
			{
				Dispatcher.Invoke((ThreadStart)delegate()
				{
					if (fldocLog.Blocks.Count > 100)
						fldocLog.Blocks.Remove(fldocLog.Blocks.FirstBlock);
					Run rch = new Run(msg);
					Paragraph pch = new Paragraph(rch);
					pch.Foreground = scb;
					fldocLog.Blocks.Add(pch);
					if (LogIsAutoScrolling == true)
						rtxtLog.ScrollToEnd();
				}, null);
			}
			//else
			//{
			//    Dispatcher.Invoke((ThreadStart)delegate()
			//    {
			//        if (fldocLog.Blocks.Count > 100)
			//            fldocLog.Blocks.Remove(fldocLog.Blocks.FirstBlock);
			//        Run rch = new Run(msg);
			//        Paragraph pch = new Paragraph(rch);
			//        pch.Foreground = scb;
			//        fldocLog.Blocks.Add(pch);
			//        rtxtLog.ScrollToEnd();
			//    }, null);
			//}
		}

		private void ClearQueue_ButtonClick(object sender, RoutedEventArgs e)
		{
			lock (_objLock)
			{
				SentReceivedOc.Clear();
			}
		}

		private void ClearLog_ButtonClick(object sender, RoutedEventArgs e)
		{
			lock (_objLock)
			{
				fldocLog.Blocks.Clear();
			}
		}

		private void ReceiveData_CheckBox_CheckedUnchecked(object sender, RoutedEventArgs e)
		{
			CheckBox cb = sender as CheckBox;
			_receivingData = (cb.IsChecked == true);
			cb.Content = (_receivingData) ? "Receiving Data" : "No Receiving";
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

	public class SentReceivedItem : INotifyPropertyChangedClass
	{
		public enum DataCorrectEnum
		{
			None,
			Ok,
			Error
		}

		private string _index = "";
		public string Index
		{
			get
			{
				return _index;
			}
			set
			{
				_index = value;
			}
		}

		private string _sent = "";
		public string Sent
		{
			get
			{
				return _sent;
			}
			set
			{
				_sent = value;
			}
		}

		private string _received = "";
		public string Received
		{
			get
			{
				return _received;
			}
			set
			{
				_received = value;
			}
		}

		private DataCorrectEnum _dataCorrect = DataCorrectEnum.None;
		public DataCorrectEnum DataCorrect
		{
			get
			{
				return _dataCorrect;
			}
			set
			{
				_dataCorrect = value;
				NotifyPropertyChanged("DataCorrect");
				if (_dataCorrect == DataCorrectEnum.None)
				{
					DataCorrectImage = null;
				}
				else
				{
					DataCorrectImage = new BitmapImage();
					DataCorrectImage.BeginInit();
					if (_dataCorrect == DataCorrectEnum.Ok)
						DataCorrectImage.UriSource = new Uri("pack://application:,,,/TcpHttpTestTcpClient;component/resources/status_ok.png");
					else
						DataCorrectImage.UriSource = new Uri("pack://application:,,,/TcpHttpTestTcpClient;component/resources/status_error.png");
					DataCorrectImage.EndInit();
				}
				NotifyPropertyChanged("DataCorrectImage");
			}
		}

		private BitmapImage _dataCorrectImage = null;
		public BitmapImage DataCorrectImage
		{
			get
			{
				return _dataCorrectImage;
			}
			set
			{
				_dataCorrectImage = value;
				NotifyPropertyChanged("DataCorrectImage");
			}
		}
	}
}
