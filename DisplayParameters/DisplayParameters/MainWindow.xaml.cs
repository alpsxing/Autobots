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

using System.Threading;
using System.Net;
using System.Net.Sockets;
using System.ComponentModel;
using System.Collections;
using System.Collections.ObjectModel;
using System.Windows.Threading;
using System.Collections.Specialized;
using System.IO;
using Microsoft.Win32;

namespace DisplayParameters
{
	/// <summary>
	/// Interaction logic for MainWindow.xaml
	/// </summary>
	public partial class MainWindow : Window, INotifyPropertyChanged
	{
		private Socket _server;
		private object _objLock = new object();
		public object ObjLock
		{
			get
			{
				return _objLock;
			}
		}
		private Thread _socketThread = null;
		private bool _dataAutoScrolling = true;

		private ObservableCollection<ParameterItem> _parOc = new ObservableCollection<ParameterItem>();
		public ObservableCollection<ParameterItem> ParOc
		{
			get
			{
				return _parOc;
			}
		}

		public event PropertyChangedEventHandler PropertyChanged;
		public void NotifyPropertyChanged(string propertyName)
		{
			if (PropertyChanged != null)
				PropertyChanged(this, new PropertyChangedEventArgs(propertyName));
		}

		public MainWindow()
		{
			InitializeComponent();
			DataContext = this;
			dgTestResults.DataContext = ParOc;
			ParOc.CollectionChanged += new NotifyCollectionChangedEventHandler(ParOc_CollectionChanged);
		}

		private void ParOc_CollectionChanged(object sender, NotifyCollectionChangedEventArgs e)
		{
			if (_dataAutoScrolling == false)
				return;

			lock (ObjLock)
			{
				if (ParOc.Count < 1)
					return;
				var border = VisualTreeHelper.GetChild(dgTestResults, 0) as Decorator;
				if (border != null)
				{
					var scroll = border.Child as ScrollViewer;
					if (scroll != null) scroll.ScrollToEnd();
				}
			}
		}

		private void Window_Loaded(object sender, RoutedEventArgs e)
		{
			_socketThread = new Thread(new ThreadStart(SocketThread));
			_socketThread.Start();
		}

		private void SocketThread()
		{
			try
			{
				IPAddress ipa = Dns.GetHostAddresses("127.0.0.1")[0];
				IPEndPoint iep = new IPEndPoint(ipa, CommonOperation.SOCKET_PORT);
				_server = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
				_server.Bind(iep);
				_server.Listen(200);
				while (true)
				{
					Socket client = _server.Accept();
					ClientThread newclient = new ClientThread(client, this);
					Thread newthread = new Thread(new ThreadStart(newclient.ClientService));
					newthread.Start();
				}
			}
			catch (ThreadAbortException) { }
		}

		protected override void OnClosing(CancelEventArgs e)
		{
			if (_socketThread != null)
			{
				_socketThread.Abort();
				//_socketThread.Join();
				_socketThread = null;
			}

			if (_server != null)
			{
				_server.Close();
				_server.Dispose();
				_server = null;
			}

			base.OnClosing(e);
		}

		private void Clear_ButtonClicked(object sender, RoutedEventArgs e)
		{
			lock (ObjLock)
			{
				ParOc.Clear();
			}
		}

		private void Exit_MenuItemClicked(object sender, RoutedEventArgs e)
		{
			if (MessageBox.Show("Are you sure to close the parameter display server?", "Confirm", MessageBoxButton.YesNo, MessageBoxImage.Question)
				!= MessageBoxResult.Yes)
				return;

			if (_socketThread != null)
			{
				_socketThread.Abort();
				//_socketThread.Join();
				_socketThread = null;
			}

			if (_server != null)
			{
				_server.Close();
				_server.Dispose();
				_server = null;
			}

			System.Environment.Exit(0);
		}

		private void DataAutoScrolling_CheckedUnchecked(object sender, RoutedEventArgs e)
		{
			CheckBox cb = sender as CheckBox;
			_dataAutoScrolling = (cb.IsChecked == true) ? true : false;
		}

		private void Save_MenuItemClicked(object sender, RoutedEventArgs e)
		{
			SaveFileDialog sfd = new SaveFileDialog();
			sfd.FileName = "Parameter Value";
			sfd.DefaultExt = ".txt";
			sfd.Filter = "Parameter Value (*.txt)|*.txt";
			sfd.AddExtension = true;
			sfd.OverwritePrompt = true;
			sfd.CheckPathExists = true;
			sfd.Title = "Save Parameter Value As...";
			sfd.InitialDirectory = System.Environment.CurrentDirectory;

			bool? b = sfd.ShowDialog();
			if (b != true)
				return;

			lock (ObjLock)
			{
				try
				{
					StreamWriter sw = new StreamWriter(sfd.FileName);
					StringBuilder sb = new StringBuilder();
					foreach (ParameterItem pi in ParOc)
					{
						sb.Append(pi.ParIndex + "\t" + pi.ParName + "\t" + pi.ParValue + "\r\n");
					}
					sw.WriteLine(sb.ToString());
					sw.Flush();
					sw.Close();
				}
				catch (Exception ex)
				{
					MessageBox.Show("Cannot save " + sfd.FileName + ".\nError message :\n" + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
				}
			}
		}
	}

	public class ClientThread
	{
		public Socket _service;

		private MainWindow _mw = null;
		public MainWindow MW
		{
			get
			{
				return _mw;
			}
		}

		public ClientThread(Socket clientsocket, MainWindow mw)
		{
			_service = clientsocket;
			_mw = mw;
		}

		public void ClientService()
		{
			string data = null;
			int i = 0;
			byte[] bytes = new byte[1024];

			while ((i = _service.Receive(bytes)) != 0)
			{
				data = System.Text.Encoding.ASCII.GetString(bytes, 0, i);
				int idx = data.IndexOf(":");
				string s1 = "";
				string s2 = "";
				if (idx > -1)
				{
					s1 = data.Substring(0, idx);
					s2 = data.Substring(idx + 1);
				}
				if (s1 == null)
					s1 = "";
				if (s2 == null)
					s2 = "";
				MW.Dispatcher.Invoke((ThreadStart)delegate()
				{
					lock (MW.ObjLock)
					{
						MW.ParOc.Add(new ParameterItem()
							{
								ParIndex = (MW.ParOc.Count + 1).ToString(),
								ParName = s1,
								ParValue = s2
							});
					}
				}, null);
			}

			_service.Close();
			_service.Dispose();
		}
	}

	public class ParameterItem
	{
		private string _parIndex = "";
		public string ParIndex
		{
			get
			{
				return _parIndex;
			}
			set
			{
				_parIndex = value;
			}
		}

		private string _parName = "";
		public string ParName
		{
			get
			{
				return _parName;
			}
			set
			{
				_parName = value;
			}
		}

		private string _parValue = "";
		public string ParValue
		{
			get
			{
				return _parValue;
			}
			set
			{
				_parValue = value;
			}
		}
	}

	public interface ICommonOperation
	{
		bool SendData(string s, double data);
		bool SendData(string s, int data);
		bool SendData(string s, string data);
	}

	public class CommonOperation : ICommonOperation
	{
		public const int SOCKET_PORT = 3579;
		public const int MAX_LENGTH = 1024;
		private static object _lock = new object();

		public bool SendData(string s, double data)
		{
			string msg = s + ":" + data.ToString();
			if (msg.Length > MAX_LENGTH)
				msg = msg.Substring(0, MAX_LENGTH);
			return SendData(Encoding.ASCII.GetBytes(msg));
		}

		public bool SendData(string s, int data)
		{
			string msg = s + ":" + data.ToString();
			if (msg.Length > MAX_LENGTH)
				msg = msg.Substring(0, MAX_LENGTH);
			return SendData(Encoding.ASCII.GetBytes(msg));
		}

		public bool SendData(string s, string data)
		{
			string msg = s + ":" + data;
			if (msg.Length > MAX_LENGTH)
				msg = msg.Substring(0, MAX_LENGTH);
			return SendData(Encoding.ASCII.GetBytes(msg));
		}

		private bool SendData(byte[] data)
		{
			lock (_lock)
			{
				Socket client = null;
				IPAddress local = IPAddress.Parse("127.0.0.1");
				IPEndPoint iep = new IPEndPoint(local, CommonOperation.SOCKET_PORT);
				try
				{
					client = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
					client.Connect(iep);
				}
				catch (Exception)
				{
					MessageBox.Show("Socket error. Please check the display parameter server.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
					return false;
				}
				client.Send(data);
				client.Close();
				client.Dispose();
			}

			return true;
		}
	}
}
