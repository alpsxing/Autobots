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
using System.Threading;
using System.Net;
using System.Net.Sockets;
using System.Collections.Specialized;

namespace TcpHttpTestHttpServer
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

		//private Thread _socketThread = null;
		//private Socket _server;
        private Thread _httpThread = null;
        private HttpListener _httpServer;

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

		private void Window_Loaded(object sender, RoutedEventArgs e)
		{
            //PostLog("Starting socket thread...");
			//_socketThread = new Thread(new ThreadStart(SocketThread));
			//_socketThread.Start();
            //PostLog("Socket thread started with port 5081.");

            if (!HttpListener.IsSupported)
            {
                PostLog("HttpListener cannot be supported.");
                PostLog("Exit.");
                return;
            }

            PostLog("Starting HttpListener thread...");
            _httpThread = new Thread(new ThreadStart(HttpThread));
            _httpThread.Start();
            PostLog("HttpListener thread started.");
        }

        private void HttpThread()
        {
            try
            {
                _httpServer = new HttpListener();
				_httpServer.Prefixes.Add("http://127.0.0.1/");
				_httpServer.Prefixes.Add("http://localhost/");
				PostLog("Trying to start Http server...");
                _httpServer.Start();
                PostLog("Http server Started.");
                while (true)
                {
                    HttpListenerContext ctx = _httpServer.GetContext();
                    PostLog("Get one HttpListenerContext.");
                    Thread newthread = new Thread(new ParameterizedThreadStart(HttpRequestThread));
                    newthread.Start(ctx);
                }
            }
            catch (ThreadAbortException ex)
            {
                PostLog("HttpListener thread is aborted with the error message : " + ex.Message);
            }
        }

        private void HttpRequestThread(object obj)
        {
            HttpListenerContext ctx = obj as HttpListenerContext;
            
            HttpListenerRequest request = ctx.Request;

            string backData = "";
            if (request.HasEntityBody)
            {
                using (System.IO.Stream body = request.InputStream)
                {
                    using (System.IO.StreamReader reader = new System.IO.StreamReader(body, request.ContentEncoding))
                    {
                        backData = reader.ReadToEnd();
                    }
                }
            }
            else
                PostLog("No body.", Brushes.Red);

            string inData = backData;
            if (string.IsNullOrWhiteSpace(backData))
                backData = "No data.";
            else
                PostLog("Body : " + backData, Brushes.Blue);

            HttpListenerResponse response = ctx.Response;

            backData = backData + " : " + DateTime.Now.ToLongTimeString();
            string responseString = "<HTML><BODY>" + backData + "</BODY></HTML>";
            byte[] buffer = System.Text.Encoding.UTF8.GetBytes(responseString);

            response.ContentLength64 = buffer.Length;
            System.IO.Stream output = response.OutputStream;
            PostLog("Trying to send response...");
            output.Write(buffer, 0, buffer.Length);
            PostLog("Sent.");

            Dispatcher.Invoke((ThreadStart)delegate()
            {
                lock (ObjLock)
                {
                    SentReceivedOc.Add(new SentReceivedItem()
                    {
                        Index = (SentReceivedOc.Count + 1).ToString(),
                        ClientIP = inData,
                        Received = backData
                    });
                }
            }, null);

            PostLog("Trying to close response...");
            output.Close();
            PostLog("Closed.");
        }

        //private void SocketThread()
        //{
        //    try
        //    {
        //        IPAddress ipa = Dns.GetHostAddresses("127.0.0.1")[0];
        //        IPEndPoint iep = new IPEndPoint(ipa, 5081);
        //        _server = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        //        _server.Bind(iep);
        //        _server.Listen(200);
        //        while (true)
        //        {
        //            Socket client = _server.Accept();
        //            ClientThread newclient = new ClientThread(client, this);
        //            Thread newthread = new Thread(new ThreadStart(newclient.ClientService));
        //            newthread.Start();
        //        }
        //    }
        //    catch (ThreadAbortException) { }
        //}

		protected override void OnClosing(CancelEventArgs e)
		{
            //if (_socketThread != null)
            //{
            //    _socketThread.Abort();
            //    //_socketThread.Join();
            //    _socketThread = null;
            //}

            //if (_server != null)
            //{
            //    _server.Close();
            //    _server.Dispose();
            //    _server = null;
            //}

            if (_httpThread != null)
            {
                _httpThread.Abort();
                //_httpThread.Join();
                _httpThread = null;
            }

            if (_httpServer != null)
            {
                _httpServer.Stop();
                _httpServer.Close();
                _httpServer = null;
            }
			base.OnClosing(e);
		}
	}

	public class ClientThread
	{
		public Socket _service;
		public IPAddress _ip;

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
			_ip = ((System.Net.IPEndPoint)_service.RemoteEndPoint).Address;
			_mw = mw;
		}

		public void ClientService()
		{
			try
			{
				string data = null;
				int length = 0;
				byte[] bytes = new byte[1024];

				if ((length = _service.Receive(bytes)) == 0)
				{
					MW.PostLog("Cannot receive any data.");
					data = "";
				}
				else
				{
					data = System.Text.Encoding.ASCII.GetString(bytes, 0, length);
					MW.PostLog("Received data : " + data);

                    MW.PostLog("Trying to send \"Response : " + data + "\"...");
                    _service.Send(Encoding.ASCII.GetBytes("Response : " + data));
                    MW.PostLog("Sent.");
				}

				MW.Dispatcher.Invoke((ThreadStart)delegate()
				{
					lock (MW.ObjLock)
					{
						MW.SentReceivedOc.Add(new SentReceivedItem()
						{
							Index = (MW.SentReceivedOc.Count + 1).ToString(),
							ClientIP = _ip.ToString(),
							Received = data
						});
					}
				}, null);

				MW.PostLog("Server instance start disconnecting...");
				_service.Disconnect(false);
				MW.PostLog("Server instance start closing...");
				_service.Close();
				MW.PostLog("Server instance start disposing...");
				_service.Dispose();
			}
			catch (Exception ex)
			{
				MW.PostLog("Server instance error : " + ex.Message);
				try
				{
					_service.Disconnect(false);
				}
				catch (Exception) { }
				try
				{
					_service.Close();
				}
				catch (Exception) { }
				try
				{
					_service.Dispose();
				}
				catch (Exception) { }
			}
			MW.PostLog("Session finished.");
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

		private string _clientIP = "";
		public string ClientIP
		{
			get
			{
				return _clientIP;
			}
			set
			{
				_clientIP = value;
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
