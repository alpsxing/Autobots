using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using System.ComponentModel;
using System.Collections;
using System.Collections.ObjectModel;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Collections.Specialized;
using System.Threading.Tasks;

namespace TcpHttpTestJitServer
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

		public void PostLog(string msg)
		{
			PostLog(msg, Brushes.Black);
		}

		public void PostLog(string msg, SolidColorBrush scb)
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

		private void ClearQueue_ButtonClick(object sender, RoutedEventArgs e)
		{
			SentReceivedOc.Clear();
		}

		private void ClearLog_ButtonClick(object sender, RoutedEventArgs e)
		{
			fldocLog.Blocks.Clear();
		}

		private void Window_Load(object sender, RoutedEventArgs e)
		{
			Thread th = new Thread(new ThreadStart(StartServer));
			th.Start();
		}

		private void StartServer()
		{
			IPAddress local = IPAddress.Any;
			IPEndPoint iep = new IPEndPoint(local, 5082);
			Socket server = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
			server.Bind(iep);
			PostLog("Start listening...");
			server.Listen(100);
			PostLog("Listen started.");
			while (true)
			{
				PostLog("Start accepting...");
				Socket client = server.Accept();
				PostLog("Accepted.");
				ClientThread newClient = new ClientThread(this, client);
				Thread newThread = new Thread(new ThreadStart(newClient.ClientService));
				newThread.Start();
			}
		}
	}

	class ClientThread
	{
		public Socket _client = null;
		private MainWindow _mw = null;

		public ClientThread(MainWindow mw, Socket s)
		{
			_mw = mw;
			_client = s;
		}

		public void ClientService()
		{
			string data = null;
			byte[] bytes = new byte[1024 * 16];
			int len = 0;
			try
			{
				while ((len = _client.Receive(bytes)) != 0)
				{
					data = System.Text.Encoding.ASCII.GetString(bytes, 0, len);
					_mw.PostLog("Received : " + data);
					bytes = System.Text.Encoding.ASCII.GetBytes("Response " + data);
					_mw.PostLog("Trying sending response : Response " + data);
					_client.Send(bytes);
					_mw.PostLog("Sent.");
					_mw.Dispatcher.Invoke((ThreadStart)delegate()
					{
						_mw.SentReceivedOc.Add(new SentReceivedItem()
						{
							Index = (_mw.SentReceivedOc.Count + 1).ToString(),
							Sent = "Response " + data,
							Received = data
						});
					}, null);
				}
			}
			catch (Exception ex)
			{
				_mw.PostLog(ex.Message);
			}
			_mw.PostLog("Start closing...");
			_client.Close();
			_mw.PostLog("Closed.");
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

		private DateTime _curDateTime = DateTime.Now;
		public DateTime CurrentDateTime
		{
			get
			{
				return _curDateTime;
			}
			set
			{
				_curDateTime = value;
			}
		}

		private string _timeStamp = DateTime.Now.ToLongDateString() + " " + DateTime.Now.ToLongTimeString();
		public string TimeStamp
		{
			get
			{
				return _timeStamp;
			}
			set
			{
				_timeStamp = value;
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
