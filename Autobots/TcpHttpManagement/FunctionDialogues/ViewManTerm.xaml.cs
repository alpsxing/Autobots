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
    /// Interaction logic for ViewTerm.xaml
    /// </summary>
    public partial class ViewManTerm : Window
    {
        private ObservableCollection<TermItem> _termsOc = new ObservableCollection<TermItem>();
        public ObservableCollection<TermItem> TermsOc
        {
            get
            {
                return _termsOc;
            }
        }

        [DefaultValue("Ready")]
        public string ReadyInfo { get; set; }

        public SolidColorBrush ReadyInfoFG { get; set; }

        public ViewManTerm(string terms, bool isManterm = true)
        {
            InitializeComponent();

            if (!isManterm)
                Title = "View Terminals";

            DataContext = this;
            dgTerm.DataContext = TermsOc;

            terms = terms.Trim();
            if (!string.IsNullOrWhiteSpace(terms))
            {
                try
                {
                    string[] sa = terms.Split(new string[] { ";" }, StringSplitOptions.RemoveEmptyEntries);
                    foreach (string si in sa)
                    {
                        string[] sia = si.Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);
                        DateTime dt;
                        if (DateTime.TryParse(sia[2], out dt) == false)
                        {
                            TermsOc.Add(
                                new TermItem()
                                {
                                    Index = (TermsOc.Count + 1).ToString(),
                                    IP = sia[0],
                                    Port = sia[1],
                                    ActTimeString = "NA",
                                    SilTimeString = "NA"
                                });
                        }
                        else
                        {
                            TermsOc.Add(
                               new TermItem()
                               {
                                   Index = (TermsOc.Count + 1).ToString(),
                                   IP = sia[0],
                                   Port = sia[1],
                                   ActivatedTime = dt
                               });
                        }
                    }
                    if (TermsOc.Count == 0)
                        ReadyInfo = (isManterm) ? "No management terminals" : "No terminals";
                    else if (TermsOc.Count == 1)
                        ReadyInfo = (isManterm) ? "1 management terminal" : "1 terminal";
                    else
                        ReadyInfo = TermsOc.Count.ToString() + ((isManterm) ? " management terminals" : " terminals");
                    ReadyInfoFG = Brushes.Black;
                }
                catch (Exception)
                {
                    ReadyInfo = "Raw data error.";
                    ReadyInfoFG = Brushes.Red;
                }

                Run rch = new Run(terms);
                Paragraph pch = new Paragraph(rch);
                fldocRaw.Blocks.Add(pch);
            }
            else
            {
                ReadyInfo = (isManterm) ? "No management terminals" : "No terminals";
                ReadyInfoFG = Brushes.Black;
            }
        }
    }

    public class TermItem
    {
        [DefaultValue("1")]
        public string Index { get; set; }

        [DefaultValue("0.0.0.0")]
        public string IP { get; set; }

        [DefaultValue("0")]
        public string Port { get; set; }

        private DateTime _activatedTime = DateTime.Now;
        public DateTime ActivatedTime {
            get
            {
                return _activatedTime;
            }
            set
            {
                _activatedTime = value;
                ActTimeString = _activatedTime.Year.ToString() + "-" + 
                    _activatedTime.Month.ToString() + "-" + 
                    _activatedTime.Day.ToString() + " " + 
                    _activatedTime.Hour.ToString() + ":" +
                    _activatedTime.Minute.ToString() + ":" +
                    _activatedTime.Second.ToString();
                TimeSpan ts = DateTime.Now.Subtract(_activatedTime);
                SilTimeString = ts.Days.ToString() + " - " +
                    ts.Hours.ToString() + ":" +
                    ts.Minutes.ToString() + ":" +
                    ts.Seconds.ToString();
            }
        }

        [DefaultValue("0")]
        public string ActTimeString { get; set; }

        [DefaultValue("0")]
        public string SilTimeString { get; set; }
    }
}
