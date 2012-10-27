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

		public MainWindow()
		{
			InitializeComponent();

			DataContext = this;
			dgSentReceived.DataContext = SentReceivedOc;
            SentReceivedOc.CollectionChanged += new NotifyCollectionChangedEventHandler(SentReceivedOc_CollectionChanged);
        }

        private void SentReceivedOc_CollectionChanged(object sender, NotifyCollectionChangedEventArgs e)
        {
            //if (_dataAutoScrolling == false)
            //    return;

            //lock (ObjLock)
            {
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
                IPEndPoint iep = new IPEndPoint(local, 5080);
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
                        if (indexThread == -1)
                        {
                            Dispatcher.Invoke((ThreadStart)delegate()
                            {
                                SentReceivedOc.Add(new SentReceivedItem()
                                {
                                    Index = (SentReceivedOc.Count + 1).ToString(),
                                    Sent = TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString(),
                                    Received = receivedText
                                });
                            }, null);
                        }
                        else
                        {
                            Dispatcher.BeginInvoke((ThreadStart)delegate()
                            {
                                SentReceivedOc.Add(new SentReceivedItem()
                                {
                                    Index = (SentReceivedOc.Count + 1).ToString(),
                                    Sent = TextForSend + "-" + indexThreadDisplay + count.ToString() + " : " + index.ToString(),
                                    Received = receivedText
                                });
                            }, null);
                        }
                    }
                    client.Disconnect(false);
                }
                client.Close();
                client.Dispose();
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
            if (ServerRequest != "1")
            {
                Dispatcher.BeginInvoke((ThreadStart)delegate()
                {
                    if (fldocLog.Blocks.Count > 100)
                        fldocLog.Blocks.Remove(fldocLog.Blocks.FirstBlock);
                    Run rch = new Run(msg);
                    Paragraph pch = new Paragraph(rch);
                    pch.Foreground = scb;
                    fldocLog.Blocks.Add(pch);
                    rtxtLog.ScrollToEnd();
                }, null);
            }
            else
            {
                Dispatcher.Invoke((ThreadStart)delegate()
                {
                    if (fldocLog.Blocks.Count > 100)
                        fldocLog.Blocks.Remove(fldocLog.Blocks.FirstBlock);
                    Run rch = new Run(msg);
                    Paragraph pch = new Paragraph(rch);
                    pch.Foreground = scb;
                    fldocLog.Blocks.Add(pch);
                    rtxtLog.ScrollToEnd();
                }, null);
            }
        }

		private void ClearQueue_ButtonClick(object sender, RoutedEventArgs e)
		{
			SentReceivedOc.Clear();
		}

		private void ClearLog_ButtonClick(object sender, RoutedEventArgs e)
		{
			fldocLog.Blocks.Clear();
		}

		private void ReceiveData_CheckBox_CheckedUnchecked(object sender, RoutedEventArgs e)
		{
			CheckBox cb = sender as CheckBox;
			_receivingData = (cb.IsChecked == true);
			cb.Content = (_receivingData) ? "Receiveing Data" : "No Receiving";
		}
	}

	public class SentReceivedItem
	{
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
	}
}
