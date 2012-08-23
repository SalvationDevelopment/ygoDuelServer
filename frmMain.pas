unit frmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, IdSocketHandle, IdBaseComponent, IdComponent, IdUDPBase,
  IdUDPServer, StdCtrls, IdGlobal, IdContext, IdCustomTCPServer,
  IdTCPServer,shellapi,sys,IdBuffer, IdTCPConnection,
  IdTCPClient, IdHTTP, IdCustomHTTPServer, IdHTTPServer,IdThreadComponent,
  ExtCtrls, IdIntercept, IdServerInterceptLogBase, IdServerInterceptLogFile,
  ygo_server_userinfo,TLHelp32, IdDNSResolver,winsock,IdSync,
  IdMappedPortTCP, Crypt, StrUtils ,DateUtils;
const
  CVN_NewCopy = wm_user +200;
type
  TForm1 = class(TForm)
    IdTCPServer1: TIdTCPServer;
    Memo1: TMemo;
    IdHTTPServer1: TIdHTTPServer;
    Panel1: TPanel;
    breg: TButton;
    bserver: TButton;
    eserverpost: TEdit;
    bserverpost: TButton;
    barena: TButton;
    bmaskroom: TButton;
    Button1: TButton;
    Button2: TButton;
    ebroadcast: TEdit;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    procedure IdTCPServer1Execute(AContext: TIdContext);
    procedure IdTCPServer2Execute(AContext: TIdContext);
    procedure FormCreate(Sender: TObject);
    procedure IdTCPServer1Connect(AContext: TIdContext);
    procedure FormDestroy(Sender: TObject);
    procedure IdTCPServer1Disconnect(AContext: TIdContext);
    procedure IdTCPServer1Exception(AContext: TIdContext;
      AException: Exception);
    procedure IdHTTPServer1CommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure bserverpostClick(Sender: TObject);
    procedure barenaClick(Sender: TObject);
    procedure refUI;
    procedure bmaskroomClick(Sender: TObject);
    procedure bregClick(Sender: TObject);
    procedure bserverClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    { Private declarations }
    function replacename(str:string):string;
  public
    { Public declarations }
    exepath:string;
    canregist:boolean;
    iskeepversion:boolean;
    lasthttpget:tdatetime;
    lastjsonget:tdatetime;
    lasthttpgetString,lastjsongetstring_delphi,lastjsongetString:string;
    needcache:boolean;
  end;

var
  Form1: TForm1;
  isSTART:boolean;
  serverpost:string;
  roomlists:tstringlist;

implementation
uses ygo_client_protocol,messageSend, messagePackage, IpRtrMib, IPFunctions, IniFiles;
{$R *.dfm}

//ת��
function Str_Gb2UniCode(text: string;aw:boolean): String;
var
  i,len: Integer;
  cur: Integer;
  t: String;
  ws: WideString;
begin
  if not aw then
  begin
    Result:=text;
    exit;
  end;
  Result := '';
  ws := text;
  len := Length(ws);
  i := 1;
  while i <= len do
  begin
    cur := Ord(ws[i]);
    FmtStr(t,'%4.4X',[cur]);
    Result := Result + t;
    Inc(i);
  end;
end;





function showusername(user:tuserinfo):string;
begin
  if g_userlist.Count>0 then
  begin
    if user.isUserInList then
       result:='<font color="blue">'+user.username+'</font>'
    else
       result:='<font color="gray">'+user.username+'(δ��֤)</font>'
  end
  else
    result:=user.username;
end;

function getPort: integer;
var
  randomport:integer;
  retrycount:integer;
  function checkrandomport(ran:integer):boolean;
  var idtcpserver:tidtcpserver;
  begin
     idtcpserver:=tidtcpserver.Create(nil);
     try
      try
        idtcpserver.DefaultPort:=ran;
        idtcpserver.OnExecute:=Form1.IdTCPServer2Execute;
        idtcpserver.Active:=true;
        idtcpserver.Active:=false;
      except
        result:=false;
        exit;
      end;
      result:=true;
     finally
      idtcpserver.Free;
     end;
  end;
  const maxport=19000;
        minport=11000;
  function getarandomint():integer;
  begin
     Randomize;
     result:=0;
     while (result>maxport) or (result<minport) do
      result:=Random(maxport);
  end;
begin
  randomport:=getarandomint;
  retrycount:=0;
  while (not checkrandomport(randomport)) do
  begin
    inc(retrycount);
    if retrycount>100 then
    begin
      result:=0;
      exit;
    end;
    randomport:=getarandomint;
  end;
  result:=randomport;
end;

procedure JoinRoom(acontext:tuserinfo);
var tmproom:troom;
    i:integer;
    rule,mode:char;
    enable_priority,no_check_deck,no_shuffle_deck:string[1];
    start_lp,start_hand,draw_count:integer;
    tmpstr:string;
    strlist:tstringlist;
    exepath,exeparms,exedir:pchar;
    startupInfo :TStartupInfo;
    procedure analyzeRoom(tmproom:troom);
    begin
          rule:='0';
          mode:='0';
          enable_priority:='F';
          no_check_deck:='F';
          no_shuffle_deck:='F';
          start_lp:=8000;
          start_hand:=5;
          draw_count:=1;
          tmproom.isshow:=true;
          tmproom.ismarch:=false;
          //roomname:='00ttt5000,5,1,asd';
          //ȷ���������͡�ģʽ���Զ���
          if copy(acontext.roomname,0,2)='T#' then
          begin
             mode:='2';
          end;
          if copy(acontext.roomname,0,2)='M#' then
          begin
             mode:='1';
          end;
          if pos('$',acontext.roomname)>0 then
            tmproom.isprivate:=true
          else
            tmproom.isprivate:=false;
          if copy(acontext.roomname,0,2)='P#' then
          begin
             tmproom.ismarch:=true;
          end;
          if copy(acontext.roomname,0,3)='PM#' then
          begin
             tmproom.ismarch:=true;
             mode:='1';
          end;

         //ȷ�������JSON��
          if tmproom.isprivate then
            tmproom.roomname_json:=copy(tmproom.roomname_real,0,pos('$',tmproom.roomname_real)-1)
          else
            tmproom.roomname_json:=tmproom.roomname_real;

        //��ʾ
        if maskRoom then
        begin
          if length(tmproom.roomname_json)>6 then
            tmproom.roomname_html:=copy(tmproom.roomname_json,0,6)+'...(<font color="red" title="'+tmproom.roomname_real+'">��</font>)'
          else
            tmproom.roomname_html:=copy(tmproom.roomname_json,0,6);
        end
        else
          tmproom.roomname_html:=tmproom.roomname_json;
        //ģʽ
        if tmproom.ismarch then
        begin
           tmproom.roomname_html:=tmproom.roomname_html+'<font color="d28311" title="������ģʽ">[��]</font>'
        end;
        //˽��
        if tmproom.isprivate then
        begin
           tmproom.roomname_html:=tmproom.roomname_html+'<font color="red" title="���뷿��">[��]</font>'
        end;
        
         //�Զ��� 
          if length(acontext.roomname)>13 then
          begin
             tmpstr:=copy(acontext.roomname,6,length(acontext.roomname));
             strlist:=tstringlist.Create;
             try
                try
                 strlist.DelimitedText:=tmpstr;
                 strlist.Delimiter:=',';
                 start_lp:=strtoint(strlist[0]);
                 start_hand:=strtoint(strlist[1]);
                 draw_count:=strtoint(strlist[2]);
                 rule:=acontext.roomname[1];
                 mode:=acontext.roomname[2];
                 enable_priority:=uppercase(acontext.roomname[3]);
                 no_check_deck:=uppercase(acontext.roomname[4]);
                 no_shuffle_deck:=uppercase(acontext.roomname[5]);
                except
                    rule:='0';
                    mode:='0';
                    enable_priority:='F';
                    no_check_deck:='F';
                    no_shuffle_deck:='F';
                    start_lp:=8000;
                    start_hand:=5;
                    draw_count:=1;
                end;
             finally
                strlist.Free;
             end;
          end;
    end;
begin
  if not tuserinfo(acontext).Connection.Connected then
     exit;

  if tuserinfo(acontext).isbaned then exit;

  EnterCriticalSection(sys_LOCKroom);
  try
    //�ҷ���
    for i:=0 to HASH_ROOM.Count-1 do
    begin
        if troom(HASH_room[I]).roomname_real=acontext.roomname then
        begin
          //��������ע�᲻�ý���
          if troom(HASH_room[I]).ismarch and (not tuserinfo(acontext).isUserInList) then
          begin
            tuserinfo(acontext).postandexit('��������ע���û����ܼ���');
            exit;
          end;
          //��������Ѿ���ʼ���˳�
          if troom(HASH_room[I]).duelstart then
          begin
           tuserinfo(acontext).postandexit('�����ѿ�ʼ���޷�����');
           exit;
          end;
          //��������û���Ϣ
          tmproom:=HASH_room[I];
          tmproom.userlist.Add(acontext);
          acontext.room:=HASH_room[I];
          exit;
        end;
    end;

    if not tuserinfo(acontext).isUserInList and (g_userlist.Count>0) then
    begin
       tuserinfo(acontext).postandexit('��ע���û����ܽ���');
       exit;
    end;
    //�Ҳ���
    if acontext.room=nil then
    begin
        //������
        tmproom:=troom.Create(form1);
        try
          tmproom.roomname_real:=acontext.roomname;
          analyzeRoom(tmproom);
          tmproom.roomport:=getPort;
          if tmproom.roomport=0 then
          begin
            tmproom.free;
            exit;
          end;
          tmproom.creator:=acontext;
 
          //need
          tmpstr:= inttostr(tmproom.roomport)+' 0 '+rule+' '+mode+' '+enable_priority+' '
                          +no_check_deck+' '+no_shuffle_deck+' '+inttostr(start_lp)+' '+inttostr(start_hand)+' '+inttostr(draw_count);
          //roomlists.Add(tmpstr);
          //postmessage(form1.Handle,CVN_NewCopy,0,0);
          exepath:=pchar(ExtractFilePath(ParamStr(0))+'ygocore.exe');
          exeparms:=pchar(inttostr(tmproom.roomport)+' 0 '+rule+' '+mode+' '+enable_priority+' '
                          +no_check_deck+' '+no_shuffle_deck+' '+inttostr(start_lp)+' '+inttostr(start_hand)+' '+inttostr(draw_count));
          exedir:=pchar(ExtractFilePath(ParamStr(0)));

          FillChar(startupInfo,sizeof(StartupInfo),0);

          //����һ��YGOCORE����
          if not CreateProcess(nil,pchar(exepath+' '+exeparms),Nil,Nil,True,CREATE_NO_WINDOW,Nil,exedir,startupInfo,tmproom.roomprocess) then
          begin
            tmproom.Free;
            form1.Memo1.Lines.Add('room create fail');
            acontext.room:=nil;
            exit;
          end;   
                     
          HASH_room.Add(tmproom);
          tmproom.userlist:=tlist.Create;
          tmproom.userlist.Add(acontext);
          acontext.room:=tmproom;
        except
          acontext.room:=nil;
          tmproom.Free;
        end;
    end;
  finally
    LeaveCriticalSection(sys_LOCKroom);
  end;
end;




procedure TForm1.IdTCPServer1Execute(AContext: TIdContext);
var i:integer;
    stream:tmemorystream;
    recv:pointer;
    buff:TIdBytes;
    name,pass:string;
    //maincardnum,sidebum:integer;
begin
    AContext.Connection.IOHandler.ReadBytes(buff,2,false);
    i:=BytesToWord(buff);
    stream:=tmemorystream.Create;
    try
        assert(i<2000);
        AContext.Connection.IOHandler.ReadStream(stream,i);
        recv:=stream.Memory;
        if tuserinfo(acontext).isbaned then exit;
        case ord(tpackage(recv^).protocolhead1) of
          CTOS_PLAYER_INFO://��һ�������û���Ϣ
          begin
            tuserinfo(AContext).username:=tDuelPlayer(recv^).name;
            if g_userlist.Count>0 then//�����Ҫ��ʵ����֤
            begin
                //��ȡ�û���Ϣ
                try
                  i:=pos('$',tuserinfo(AContext).username);
                  if i=0 then//�Ҳ�������Ͳ���֤
                     tuserinfo(AContext).isUserInList:=false;
                  if i>0 then
                  begin
                      name:=copy(tuserinfo(AContext).username,0,i-1);
                      pass:=copy(tuserinfo(AContext).username,i+1,length(tuserinfo(AContext).username)-1);
                      tuserinfo(AContext).username:=replacename(name);
                      tuserinfo(AContext).uerpass:=encryptString(pass);
                      if  tuserinfo(AContext).uerpass='' then
                      begin
                        tuserinfo(acontext).postandexit('�޷�ͨ����֤����ȷ�Ϻ�����');
                        exit;
                      end;

                      if g_userlist.values[tuserinfo(AContext).username]<>tuserinfo(AContext).uerpass then
                      begin
                         tuserinfo(acontext).postandexit('�޷�ͨ����֤����ȷ�Ϻ�����');
                         exit;
                      end;
                      tuserinfo(AContext).isUserInList:=true;
                      StringToWideChar(tuserinfo(AContext).username,tDuelPlayer(recv^).name,19);
                  end;
                except
                  tuserinfo(AContext).isUserInList:=false;
                end;
            end;
            move(recv^,tuserinfo(AContext).userlogininfo,41);//��¼�µ�¼�İ�
          end;
          //����һ����Ϸ
          CTOS_JOIN_GAME://�ڶ�������������Ϸ��ʹ��������Ϊ������
          begin
            if not tuserinfo(acontext).connected then exit; 
            //Memo1.Lines.Add(tDuelRoom(recv^).password2name);
            //�汾ȷ��102C
            //showmessage(inttostr(ord(tDuelRoom(recv^).seed[0])));
            if not ((ord(tDuelRoom(recv^).seed[1])=18)
              and (ord(tDuelRoom(recv^).seed[0])=208)) then
            begin
              tuserinfo(acontext).postandexit('�汾102D0����ȷ��');
              //memo1.Lines.Add(tuserinfo(AContext).username+'dissconnect �汾����ȷ');
             // acontext.Connection.Disconnect;
              exit;
            end;
            tuserinfo(AContext).roomname:= replacename(tDuelRoom(recv^).password2name);
            if tuserinfo(AContext).roomname='' then
            begin
              //memo1.Lines.Add(tuserinfo(AContext).username+'dissconnect cause noroomname');
              tuserinfo(acontext).postandexit('����Ϊ�գ����޸ķ�����');
              exit;
            end;
            //��ʼ���ҷ��䣬����Ҳ����ʹ���һ��
            JoinRoom(tuserinfo(AContext));
            sleep(500);
            //ygocore.exe 7933 0 0 t t t 1000 1 1
            if tuserinfo(AContext).room=nil then exit;
            //����һ��TCP�ͻ���
            try
              tuserinfo(AContext).CreateRoomClient;
            except
              exit;
            end;
          end;
        end;
        //�ѵ�ǰ�İ���������������
        if assigned(tuserinfo(AContext).peerTcpClient) then
          if tuserinfo(AContext).peerTcpClient.Connected then
            sendstream(tuserinfo(AContext).peerTcpClient,tuserinfo(AContext).sendlock,stream);
    finally
      stream.Free;
    end;
end;

procedure TForm1.IdTCPServer2Execute(AContext: TIdContext);
begin
   AContext.Connection.Disconnect;
end;

function HostToIP(Name: string; var Ip: string): Boolean;   //hosttoip ���������ǽ�����������ip
var
wsdata : TWSAData;
hostName : array [0..255] of char;
hostEnt : PHostEnt;
addr : PChar;
begin
WSAStartup ($0101, wsdata);
try
    gethostname (hostName, sizeof (hostName));
    StrPCopy(hostName, Name);
    hostEnt := gethostbyname (hostName);
    if Assigned (hostEnt) then
      if Assigned (hostEnt^.h_addr_list) then begin
        addr := hostEnt^.h_addr_list^;
        if Assigned (addr) then begin
          IP := Format ('%d.%d.%d.%d', [byte (addr [0]),
          byte (addr [1]), byte (addr [2]), byte (addr [3])]);
          Result := True;
        end
        else
          Result := False;
      end
      else
        Result := False
    else begin
      Result := False;
    end;
finally
    WSACleanup;
end
end;



procedure TForm1.FormCreate(Sender: TObject);
var strlist:tstringlist;
begin
  iskeepversion:=false;
  canregist:=false;
  isarena:=false;
  exepath:= ExtractFilePath(Application.ExeName);
  Idtcpserver1.ContextClass:=tuserinfo;
  InitializeCriticalSection(sys_LOCKroom);
  InitializeCriticalSection(sys_LOCKFile);
  g_userlist:=tstringlist.Create;
  if fileexists(exepath+'userlist.conf') then
  g_userlist.LoadFromFile(exepath+'userlist.conf');
  lasthttpget:=now();
  lastjsonget:=now();
  needcache:=true;
  

  HASH_ROOM:=tlist.Create;
  isSTART:=true;
  if fileexists(exepath+'server.conf') then
  begin
    try
       strlist:=tstringlist.Create;
       try
           strlist.LoadFromFile(exepath+'server.conf');
           if strlist.Values['canRegist']<>'' then
           canregist:=strtobool(strlist.Values['canRegist']);
           serverPort:=strtoint(strlist.Values['serverPort']);
           serverHTTPPort:=strtoint(strlist.Values['serverHTTPPort']);
           serverDisplayIP:=strlist.Values['serverDisplayIP'];
           historyPublicURL:=strlist.Values['historyPublicURL'];
           serverLogo :=strlist.Values['serverLogo'];
           managepass:=strlist.Values['managepass'];
           maxuser:=strtoint(strlist.Values['maxuser']);
           serverURL:=strlist.Values['serverURL'];
           needcache:=strtobool(strlist.Values['needHttpCache']);
           if managepass='' then managepass:='showme';
         
           if uppercase(strlist.Values['maskRoom'])='TRUE' then
              maskRoom:=true
           else
              maskRoom:=false;
              
           if uppercase(strlist.Values['recordReplay'])='TRUE' then
              needrecordReplay:=true
           else
              needrecordReplay:=false;
       finally
          strlist.Free;
       end;
    except
      showmessage('�����ļ����ڴ���');
      exit;
    end;
  end;
  if serverDisplayIP='' then
    HostToIP(serverURL,serverDisplayIP);

  Idtcpserver1.DefaultPort:=serverPort;
  IdHTTPServer1.DefaultPort:=serverHTTPPort;
  Idtcpserver1.Active:=true;
  IdHTTPServer1.Active:=true;
  refui;
  memo1.Lines.Add('��ս����������:'+inttostr(serverport));
  memo1.Lines.Add('WEB����������:'+inttostr(serverHTTPport));
  memo1.Lines.Add('�ӱ����Ϣ�������ļ�:server.conf�޸���Ӧ����');
  memo1.Lines.Add('��һ���û�ע��󳡵�|���������Ч');
  memo1.Lines.Add('ע��ҳ��ģ��Ϊ:regist.html�������ҿռ䰲��');
  memo1.Lines.Add('�޸����е�: var serverurl=''http://127.0.0.1:7922/''Ϊ���ӷ�������Ӧ��HTTP����');
  memo1.Lines.add('��������������ϸ�Ķ������ĵ������κβ�����ĵط���GOOGLE��������');
end;

procedure TForm1.IdTCPServer1Connect(AContext: TIdContext);
begin
  tuserinfo(acontext).connected:=false;
  if sys_LOCKroom.LockCount>4 then
  begin
    tuserinfo(acontext).postandexit('��������æ�����Ժ�����');
    exit;
  end;
  
  tuserinfo(acontext).connected:=true;

  if not isSTART then
  begin
    tuserinfo(acontext).postandexit('��������ͣ����');
    sleep(3000);
    tuserinfo(acontext).Connection.Disconnect;
    exit;
  end;

  if HASH_ROOM.Count>maxuser then
  begin
    tuserinfo(acontext).postandexit('����������');
    exit;
  end;
  tuserinfo(acontext).Connection.Socket.ReadTimeout:=1800000;
  tuserinfo(acontext).Connection.Socket.UseNagle:=false;
end;

procedure TForm1.IdTCPServer1Disconnect(AContext: TIdContext);
var i:integer;
f:TFormatSettings;
begin
      if not tuserinfo(acontext).connected then exit;
      tuserinfo(AContext).connected:=false;
      tuserinfo(AContext).isbaned:=true;

      EnterCriticalSection(sys_LOCKroom);
      try
         if assigned(tuserinfo(Acontext).room) then
         if tuserinfo(AContext).room<>nil then  //ɾ��������û��б��ж�Ӧ���û���Ϣ
         begin
           if tuserinfo(AContext).room.userlist<>nil then
           begin
            //ɾ������ı��û���Ϣ
            tuserinfo(AContext).room.userlist.Remove(Acontext);
            tuserinfo(AContext).room.userlist.pack;
           end;
          if tuserinfo(acontext).room.creator = acontext then   //����Ĵ����ߣ����ͷ����еķ�����Դ
          begin
              //ɱ������
              TerminateProcess(tuserinfo(AContext).room.roomprocess.hProcess,0);

              //�ܱ����Ƴ�������
              HASH_ROOM.Remove(tuserinfo(AContext).room);
              HASH_ROOM.Pack;

              //�ͷ�ROOM��Դ
              for i:=0 to tuserinfo(AContext).room.userlist.Count-1 do
              begin//�����û������ÿ�
                 if tuserinfo(tuserinfo(AContext).room.userlist[i]).Connection.Connected then
                    tuserinfo(tuserinfo(AContext).room.userlist[i]).Connection.Disconnect;
                 tuserinfo(tuserinfo(AContext).room.userlist[i]).room:=nil;
              end;
              //ɾ����ʱreplay
             if tuserinfo(AContext).room.duelstart then
              if not tuserinfo(AContext).room.recorded then
                if DirectoryExists(ExtractFilePath(ParamStr(0))+'replay_error\') then
                   if fileexists(ExtractFilePath(ParamStr(0))+'replay\'+inttostr(tuserinfo(AContext).room.roomport)+'Replay.yrp') then
                   begin
                      f.ShortDateFormat:='yyyy-MM-dd';
                      f.LongTimeFormat:='hh-mm-ss-ZZZ';
                      copyfile(pchar(ExtractFilePath(ParamStr(0))+'replay\'+inttostr(tuserinfo(AContext).room.roomport)+'Replay.yrp'),
                      pchar(ExtractFilePath(ParamStr(0))+'replay_error\'+datetimetostr(now(),f)+'='
                      +tuserinfo(AContext).room.player1+'='+tuserinfo(AContext).room.player2
                      +'='+booltostr(tuserinfo(AContext).room.player1reg)+'='+booltostr(tuserinfo(AContext).room.player2reg)
                      +'='+inttostr(tuserinfo(AContext).room.winner)+'='+inttostr(tuserinfo(AContext).room.wincause)+'.yrp'),false);
                   end;
                                                          
              if fileexists(ExtractFilePath(ParamStr(0))+'replay\'+inttostr(tuserinfo(AContext).room.roomport)+'Replay.yrp') then
                  deletefile(ExtractFilePath(ParamStr(0))+'replay\'+inttostr(tuserinfo(AContext).room.roomport)+'Replay.yrp');
              //�ͷ��û��б�
              freeandnil(tuserinfo(AContext).room.userlist);
              //�ͷű�����
              freeandnil(tuserinfo(AContext).room);
          end;
         end;
      finally
         leaveCriticalSection(sys_LOCKroom);
      end;
end;

procedure TForm1.IdTCPServer1Exception(AContext: TIdContext;
  AException: Exception);
begin
  //memo1.Lines.Add(datetimetostr(now())+tuserinfo(AContext).username+'error diss:'+AException.Message);
  AContext.Connection.Disconnect;
end;

procedure TForm1.IdHTTPServer1CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  var i,j,hiddennum:integer;
      transcode:boolean;
begin
      hiddennum:=0;//��Ҫ���صķ����
      //����
      AResponseInfo.ContentType:='text/html';
      if ARequestInfo.Params.Values['operation']='passcheck' then
      begin
         if g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])]=EncryptString(ARequestInfo.Params.Values['pass']) then
              AResponseInfo.ContentText:='true'
         else
              AResponseInfo.ContentText:='false';
         exit;
      end;

      if (ARequestInfo.Params.Values['operation']='getroomjson') or (ARequestInfo.Params.Values['operation']='getroomjsondelphi') then
      begin
         if ARequestInfo.Params.Values['operation']='getroomjsondelphi' then
             transcode:=true;

         if (SecondsBetween(now,lastjsonget)<2) and needcache then
         begin
            if transcode then
              AResponseInfo.ContentText:=lastjsongetstring
            else
              AResponseInfo.ContentText:=lastjsongetstring_delphi;
            exit;
         end;
         
         if tryEnterCriticalSection(sys_LOCKroom) then
         begin
             try
                AResponseInfo.ContentText:='{"rooms":[';
                for i:= hash_room.Count-1 downto 0 do
                begin
                    //�Ƿ���ʾ����Ĵ���
                    if troom(HASH_room[I]).roomport=hiddennum then troom(HASH_room[I]).isshow:=false;
                    if not troom(HASH_room[I]).isshow then continue;
                    if i<hash_room.Count-1 then AResponseInfo.ContentText:=AResponseInfo.ContentText+',';
                    AResponseInfo.ContentText:=AResponseInfo.ContentText+'{"roomid":"'+inttostr(troom(HASH_room[I]).roomport)
                            +'","roomname":"'+Str_Gb2UniCode(troom(HASH_room[I]).roomname_json,transcode)+'"';
                    if troom(HASH_room[I]).isprivate then
                      AResponseInfo.ContentText:=AResponseInfo.ContentText+',"needpass":"true"'
                    else
                      AResponseInfo.ContentText:=AResponseInfo.ContentText+',"needpass":"false"';
                      
                    AResponseInfo.ContentText:=AResponseInfo.ContentText+',"users":[';
                    for j:=0 to troom(HASH_room[I]).userlist.Count-1 do
                    begin
                      if j>0 then AResponseInfo.ContentText:=AResponseInfo.ContentText+',';
                      
                       AResponseInfo.ContentText:=AResponseInfo.ContentText+'{"id":"'+booltostr(tuserinfo(troom(HASH_room[I]).userlist[j]).isUserInList);
                       AResponseInfo.ContentText:=AResponseInfo.ContentText+'","name":"'+Str_Gb2UniCode(tuserinfo(troom(HASH_room[I]).userlist[j]).username,transcode);
                       AResponseInfo.ContentText:=AResponseInfo.ContentText+'","pos":"'+inttostr(tuserinfo(troom(HASH_room[I]).userlist[j]).pos)+'"}';
                    end;
                    AResponseInfo.ContentText:=AResponseInfo.ContentText+']';

                    if troom(HASH_room[I]).duelstart then
                       AResponseInfo.ContentText:=AResponseInfo.ContentText+',"istart":"start"}'
                    else
                       AResponseInfo.ContentText:=AResponseInfo.ContentText+',"istart":"wait"}';
                end;
                AResponseInfo.ContentText:=AResponseInfo.ContentText+']}';
                if transcode then
                  lastjsongetstring:=AResponseInfo.ContentText
                else
                  lastjsongetstring_delphi:=AResponseInfo.ContentText;
                lastjsonget:=now();
               // AResponseInfo.ContentText:=UnicodeEncode(AResponseInfo.ContentText,CP_OEMCP);
             finally
                 leaveCriticalSection(sys_LOCKroom);
             end;
         end
         else
           AResponseInfo.ContentText:='[server busy]';
         exit;
      end;

      //�����
      if ARequestInfo.Params.Values['pass']=managepass then
      begin
        if ARequestInfo.Params.Values['operation']='close' then
        begin
           isSTART:=false;
           AResponseInfo.ContentText:='�����������ر�';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='forceuserpass' then
        begin
           ARequestInfo.Params.Values['username']:=replaceName(ARequestInfo.Params.Values['username']);

           g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])]:=EncryptString(ARequestInfo.Params.Values['password']);
            caption:=g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])];
           AResponseInfo.ContentText:='ok';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='serverpost' then
        begin
          serverpost:=utf8toansi(ARequestInfo.Params.Values['serverpost']);   
        end;

        if ARequestInfo.Params.Values['operation']='start' then
        begin
           isSTART:=true;
           AResponseInfo.ContentText:='��������������';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='maskroom' then
        begin
           maskRoom:=true;
           AResponseInfo.ContentText:='�������ƿ���';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='unmuskroom' then
        begin
           maskRoom:=false;
           AResponseInfo.ContentText:='�������ƹر�';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='reloaduser' then
        begin
           g_userlist.Clear;
           if fileexists(exepath+'userlist.conf') then
              g_userlist.LoadFromFile(exepath+'userlist.conf');
           AResponseInfo.ContentText:='�û��������';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='saveuser' then
        begin
           if iskeepversion then exit;
           g_userlist.SaveToFile(exepath+'userlist.conf');
           AResponseInfo.ContentText:='�û��������';
           exit;
        end;
        
        if ARequestInfo.Params.Values['operation']='openreg' then
        begin
           if iskeepversion then exit;
           canregist:=true;
           AResponseInfo.ContentText:='������ע�Ὺ��';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='arenastart' then
        begin
            if iskeepversion then exit;
            isarena:=true;
            AResponseInfo.ContentText:='����|������Ч������';
            exit;
        end;

        if ARequestInfo.Params.Values['operation']='arenastop' then
        begin
            if iskeepversion then exit;
            isarena:=false;
            AResponseInfo.ContentText:='����|������Ч���ر�';
            exit;
        end;

        if ARequestInfo.Params.Values['operation']='closereg' then
        begin
           if iskeepversion then exit;
           canregist:=false;
           AResponseInfo.ContentText:='������ע��ر�';
           exit;
        end;

        if ARequestInfo.Params.Values['operation']='hiddenroom' then
        begin
           if ARequestInfo.Params.Values['roomid']<>'' then
           begin
               try
                  hiddennum:=strtoint(ARequestInfo.Params.Values['roomid']);
               except
               end;
           end;
        end;
      end;
      if ARequestInfo.Params.Values['pass']<>'' then
        if ARequestInfo.Params.Values['pass']<>managepass then
        begin
           AResponseInfo.ContentText:='�������';
           exit;
        end;
  //ע���
       if ARequestInfo.Params.Values['userregist']<>'' then
       begin
          if not canregist then
          begin
              AResponseInfo.ContentText:='�û�ע���ֹ';
              exit;
          end;
          
          if uppercase(ARequestInfo.Params.Values['userregist'])='NEW' then
          begin
              if g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])]<>'' then
              begin
                  AResponseInfo.ContentText:='�û��Ѵ���';
                  exit;
              end;
              if (ARequestInfo.Params.Values['username']<>'') and (ARequestInfo.Params.Values['password']<>'') then
              begin
                ARequestInfo.Params.Values['username']:=replaceName(ARequestInfo.Params.Values['username']);
                g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])]:=EncryptString(ARequestInfo.Params.Values['password']);
                AResponseInfo.ContentText:=ARequestInfo.Params.Values['username']+'ע��ɹ�';
                g_userlist.SaveToFile(exepath+'userlist.conf');
                exit;
              end
              else
              begin
                AResponseInfo.ContentText:='ע��ʧ��';
                exit;
              end;
          end;
          if uppercase(ARequestInfo.Params.Values['userregist'])='CHANGEPASS' then
          begin
             if g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])]<>EncryptString(ARequestInfo.Params.Values['oldpass']) then
             begin
                  AResponseInfo.ContentText:='�û������벻ƥ��';
                  exit;
             end
             else
             begin
                g_userlist.Values[utf8toansi(ARequestInfo.Params.Values['username'])]:=EncryptString(ARequestInfo.Params.Values['password']);
                AResponseInfo.ContentText:='�޸ĳɹ�';
                exit;
             end;
          end;
       end;
  if ARequestInfo.Params.Values['adv']<>'' then
  begin
     AResponseInfo.ContentText:='<head>'+#10#13
          +'<meta http-equiv="Content-Type" content="text/html; charset=gb2312" />'+#10#13
          +'<meta name ="keywords" content="��Ϸ��,�Զ�����ս,������,�����սƽ̨,��Ϸ,������Ϸ,�������"> '+#10#13
          +'<title>DUEL SERVER</title>'+#10#13
          +'</head>'+#10#13;
     AResponseInfo.ContentText:=AResponseInfo.ContentText+'<div style="width:468px;position:absolute; left:0px; top:0px; height:100px;">'+#10#13;
      AResponseInfo.ContentText:=AResponseInfo.ContentText+'<script type="text/javascript"><!--'+#10#13
          +'google_ad_client = "ca-pub-9520543693264555";'+#10#13
          +'/* YGOad */'+#10#13
          +'google_ad_slot = "2745459735";'+#10#13 
          +'google_ad_width = 468;'+#10#13
          +'google_ad_height = 60;'+#10#13
          +'//-->'+#10#13
          +'</script>'+#10#13
          +'<script type="text/javascript" src="http://pagead2.googlesyndication.com/pagead/show_ads.js">'+#10#13
          +'</script></div>'+#10#13;
      exit;
  end;

   if (SecondsBetween(now,lasthttpget)<2) and needcache then
   begin
      AResponseInfo.ContentText:=lasthttpgetstring;
      exit;
   end;

  //������״̬��ʾ
  if tryEnterCriticalSection(sys_LOCKroom) then
  begin
       try
        AResponseInfo.ContentText:='<head>'+#10#13
          +'<meta http-equiv="Content-Type" content="text/html; charset=gb2312" />'+#10#13
          +'<meta name ="keywords" content="��Ϸ��,�Զ�����ս,������,�����սƽ̨,��Ϸ,������Ϸ,�������"> '+#10#13
          +'<title>DUEL SERVER</title>'+#10#13
          +'</head>'+#10#13;
        AResponseInfo.ContentText:=AResponseInfo.ContentText+'<div align="center"><img src="'+serverLogo+' "></img></div><div style="width:468px;position:absolute; right:10px; top:137px; height:100px;">'+#10#13;
        AResponseInfo.ContentText:=AResponseInfo.ContentText+'<script type="text/javascript"><!--'+#10#13
          +'google_ad_client = "ca-pub-9520543693264555";'+#10#13
          +'/* YGOad */'+#10#13
          +'google_ad_slot = "2745459735";'+#10#13 
          +'google_ad_width = 468;'+#10#13
          +'google_ad_height = 60;'+#10#13
          +'//-->'+#10#13
          +'</script>'+#10#13
          +'<script type="text/javascript" src="http://pagead2.googlesyndication.com/pagead/show_ads.js">'+#10#13
          +'</script></div>'+#10#13;
        AResponseInfo.ContentText:=AResponseInfo.ContentText+'<br/>��ǰ��������:'+inttostr(HASH_ROOM.Count)+'/'+inttostr(maxuser)+'������������ַ��'+serverDisplayIP;



        if needrecordReplay then
            AResponseInfo.ContentText:=AResponseInfo.ContentText+'������<a href="'+historyPublicURL+'" target="_blank" style="color:red">��ʷ��ս��¼</a>';

        if maskRoom then
            AResponseInfo.ContentText:=AResponseInfo.ContentText+'������<div style="color:red" title="��������ģʽ��ֻ��ʾ������û�ID��ǰ5λ">��������ģʽ</div>';

        if g_userlist.Count>0 then
            AResponseInfo.ContentText:=AResponseInfo.ContentText+'������<div style="color:green; float:left" title="���ų���|�������ֻ����ͨ��ʵ����֤���û��������䣬����͵��ų���|������һ�𷢶�">[���ų���|�������]</div>';

        if isarena then
            AResponseInfo.ContentText:=AResponseInfo.ContentText+'������<div style="color:red; float:left" title="���ų���|����������ģʽ��M#���䲻����¼������͵��ų���|�������һ�𷢶�">[���ų���|������]</div>';

        AResponseInfo.ContentText:=AResponseInfo.ContentText+'<br/>';

        if serverpost<>'' then
        AResponseInfo.ContentText:=AResponseInfo.ContentText+'<div style="color:red" >���棺'+serverpost+'</div>';

        if isSTART then
          AResponseInfo.ContentText:=AResponseInfo.ContentText+'������״̬������'
        else
          AResponseInfo.ContentText:=AResponseInfo.ContentText+'������״̬���ر�';
        AResponseInfo.ContentText:=AResponseInfo.ContentText+'</br>';
        AResponseInfo.ContentText:=AResponseInfo.ContentText+'<hr/>';
        for i:= hash_room.Count-1 downto 0 do
        begin
            //�Ƿ���ʾ����Ĵ���
            if troom(HASH_room[I]).roomport=hiddennum then troom(HASH_room[I]).isshow:=false;
            if not troom(HASH_room[I]).isshow then continue;

            if troom(HASH_room[I]).duelstart then
                AResponseInfo.ContentText:=AResponseInfo.ContentText+'<div style="width:300px; height:150px; border:1px #ececec solid; float:left;padding:5px; margin:5px;">�������ƣ�'+troom(HASH_room[I]).roomname_html+' <font color=red>�����ѿ�ʼ!</font>'
            else
                AResponseInfo.ContentText:=AResponseInfo.ContentText+'<div style="width:300px; height:150px; border:1px #ececec solid; float:left;padding:5px; margin:5px;">�������ƣ�'+troom(HASH_room[I]).roomname_html+' <font color=blue>�ȴ�</font>';
            AResponseInfo.ContentText:=AResponseInfo.ContentText+'<font size="1">(ID��'+inttostr(troom(HASH_room[I]).roomport)+')</font>';

            if assigned(troom(HASH_room[I]).userlist) then
            for j:=0 to troom(HASH_room[I]).userlist.Count -1 do
            begin
              if assigned(tuserinfo(troom(HASH_room[I]).userlist[j])) then
              begin
                  case tuserinfo(troom(HASH_room[I]).userlist[j]).pos of
                  0,16:
                     AResponseInfo.ContentText:=AResponseInfo.ContentText+'<li>===����1='
                    +showusername(tuserinfo(troom(HASH_room[I]).userlist[j]))+';</li>';
                  1,17:
                     AResponseInfo.ContentText:=AResponseInfo.ContentText+'<li>===����2='
                    +showusername(tuserinfo(troom(HASH_room[I]).userlist[j]))+';</li>';
                  else
                   AResponseInfo.ContentText:=AResponseInfo.ContentText+'<li>��������ս��'
                    +showusername(tuserinfo(troom(HASH_room[I]).userlist[j]))+';</li>';
                   end;
              end;
            end;
            AResponseInfo.ContentText:=AResponseInfo.ContentText+'</div>';
        end;
        lasthttpgetstring:=AResponseInfo.ContentText;
        lasthttpget:=now;
      finally
         leaveCriticalSection(sys_LOCKroom);
      end;
  end
  else
    AResponseInfo.ContentText:='������æ�����Ժ�����ˢ��;';
end;


procedure TForm1.bserverpostClick(Sender: TObject);
begin
   serverpost:=eserverpost.Text;
   refui;
end;

procedure TForm1.barenaClick(Sender: TObject);
begin
  isarena:=not isarena;
  refui;
end;

procedure TForm1.refUI;
begin
  if iskeepversion then
  begin
     // breg.Visible:=false;
      Button1.Visible:=false;
      barena.Visible:=false;
  end;

  if isarena then
    barena.Caption:='������������'
  else
    barena.Caption:='�������ѹر�';

  if maskRoom then
    bmaskRoom.Caption:='��������������'
  else
    bmaskRoom.Caption:='���������ѹر�';

  if canregist then
    breg.Caption:='������ע��'
  else
    breg.Caption:='�ѹر�ע��';

  if isSTART then
    bserver.Caption:='����������'
  else
    bserver.Caption:='������ͣ';

  if needcache then
    button5.Caption:='�����û���'
  else
    button5.Caption:='δ���û���';

  eserverpost.Text:=serverpost;
end;

procedure TForm1.bmaskroomClick(Sender: TObject);
begin
   maskRoom:=not maskRoom;
   refui;
end;

procedure TForm1.bregClick(Sender: TObject);
begin
  canregist:=not canregist;
  refui;
end;

procedure TForm1.bserverClick(Sender: TObject);
begin
  isSTART:=not isSTART;
  refui;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if g_userlist.Count>0 then
   g_userlist.SaveToFile(exepath+'userlist.conf');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  shellexecute(form1.Handle,'open',pchar('http://127.0.0.1:'+inttostr(serverHTTPPort)),'',nil,0);
end;
procedure TForm1.FormDestroy(Sender: TObject);
begin
  if g_userlist.Count>0 then
   g_userlist.SaveToFile(exepath+'userlist.conf');
   g_userlist.Free;
   //DeleteCriticalSection(sys_LOCKroom);
   //DeleteCriticalSection(sys_LOCKFile);
end;
function TForm1.replacename(str: string):string;
begin
  result:=str;
  result:=AnsiReplaceText(result,'"','');
  result:=AnsiReplaceText(result,'<','');
  result:=AnsiReplaceText(result,'>','');
  result:=AnsiReplaceText(result,'/','');
  result:=AnsiReplaceText(result,'\','');
  result:=AnsiReplaceText(result,' ','');
end;

procedure TForm1.Button3Click(Sender: TObject);
var i,j:integer;
    stream:tmemorystream;
    charinfo:array[0..254] of WideChar;
begin
    //charinfo.protocolhead1:=char(STOC_CHAT);

    StringToWideChar(ebroadcast.Text,@charinfo[0],250);
    EnterCriticalSection(sys_LOCKroom);
    
    try
    for i:= hash_room.Count-1 downto 0 do
        begin
            //�Ƿ���ʾ����Ĵ���
            if assigned(troom(HASH_room[I]).userlist) then
            for j:=0 to troom(HASH_room[I]).userlist.Count -1 do
            begin
              if assigned(tuserinfo(troom(HASH_room[I]).userlist[j])) then
              begin
                  sendchat(tuserinfo(troom(HASH_room[I]).userlist[j]),char(STOC_CHAT),@charinfo,250);
//                sendstream(tuserinfo(troom(HASH_room[I]).userlist[j]).peerTcpClient,tuserinfo(troom(HASH_room[I]).userlist[j]).sendlock,stream);
              end;
            end;
        end;
      finally
         leaveCriticalSection(sys_LOCKroom);
      end;

end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  g_userlist.LoadFromFile(exepath+'userlist.conf');
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  needcache:=not needcache;
  refui;
end;

end.
