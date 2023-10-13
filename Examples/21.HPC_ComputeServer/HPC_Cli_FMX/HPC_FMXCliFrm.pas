unit HPC_FMXCliFrm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Edit,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,

  Z.Net.Client.Indy, Z.DFE,
  Z.Net, Z.Core, Z.Status,
  Z.Net.DoubleTunnelIO.NoAuth, FMX.Memo.Types;

type
  TFMXDoubleClientForm = class(TForm)
    Memo1: TMemo;
    connectButton: TButton;
    HostEdit: TEdit;
    HelloWorldBtn: TButton;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure connectButtonClick(Sender: TObject);
    procedure HelloWorldBtnClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    procedure DoStatusNear(AText: string; const ID: Integer);

    procedure cmd_ChangeCaption(Sender: TPeerClient; InData: TDFE);
    procedure cmd_GetClientValue(Sender: TPeerClient; InData, OutData: TDFE);
  public
    { Public declarations }
    RecvTunnel: TZNet_Client_Indy;
    SendTunnel: TZNet_Client_Indy;
    client    : TZNet_DoubleTunnelClient_NoAuth;
  end;

var
  FMXDoubleClientForm: TFMXDoubleClientForm;

implementation

{$R *.fmx}

{ TFMXClientForm }

procedure TFMXDoubleClientForm.cmd_ChangeCaption(Sender: TPeerClient; InData: TDFE);
begin
  DoStatus('Change Caption:%s', [InData.Reader.ReadString]);
end;

procedure TFMXDoubleClientForm.cmd_GetClientValue(Sender: TPeerClient; InData, OutData: TDFE);
begin
  OutData.WriteString('getclientvalue:abc');
end;

procedure TFMXDoubleClientForm.connectButtonClick(Sender: TObject);
begin
  SendTunnel.Connect(HostEdit.Text, 9815);
  RecvTunnel.Connect(HostEdit.Text, 9816);

  // 检查双通道是否都已经成功链接，确保完成了对称加密等等初始化工作
  while (not client.RemoteInited) and (client.Connected) do
    begin
      TThread.Sleep(10);
      client.Progress;
    end;

  if client.Connected then
    begin
      // 异步方式合并两个通道
      client.TunnelLinkP(
        procedure(const State: Boolean)
        begin
          if State then
            begin
              // 双通道链接成功
              DoStatus('double tunnel link success!');
            end;
        end);
      // 同步方式合并两个通道
      // if client.TunnelLink then
      // begin
      // // 双通道链接成功
      // end;
    end;
end;

procedure TFMXDoubleClientForm.DoStatusNear(AText: string; const ID: Integer);
begin
  Memo1.Lines.Add(AText);
  Memo1.GoToTextEnd;
end;

procedure TFMXDoubleClientForm.FormCreate(Sender: TObject);
begin
  AddDoStatusHook(self, DoStatusNear);

  RecvTunnel := TZNet_Client_Indy.Create;
  SendTunnel := TZNet_Client_Indy.Create;
  client := TZNet_DoubleTunnelClient_NoAuth.Create(RecvTunnel, SendTunnel);

  client.RegisterCommand;

  // 注册可以由服务器发起的通讯指令
  client.RecvTunnel.RegisterDirectStream('ChangeCaption').OnExecute := cmd_ChangeCaption;
  client.RecvTunnel.RegisterStream('GetClientValue').OnExecute := cmd_GetClientValue;
end;

procedure TFMXDoubleClientForm.FormDestroy(Sender: TObject);
begin
  DisposeObject(client);
  DeleteDoStatusHook(self);
end;

procedure TFMXDoubleClientForm.HelloWorldBtnClick(Sender: TObject);
var
  SendDe, ResultDE: TDFE;
begin
  // 异步方式发送，并且接收Stream指令，反馈以proc回调触发
  SendDe := TDFE.Create;
  SendDe.WriteString('123456');
  client.SendTunnel.SendStreamCmdP('helloWorld_Stream_Result', SendDe,
    procedure(Sender: TPeerClient; ResultData: TDFE)
    begin
      if ResultData.Count > 0 then
          DoStatus('server response:%s', [ResultData.Reader.ReadString]);
    end);
  DisposeObject([SendDe]);

  // 阻塞方式发送，并且接收Stream指令
  SendDe := TDFE.Create;
  ResultDE := TDFE.Create;
  SendDe.WriteString('654321');
  client.SendTunnel.WaitSendStreamCmd('helloWorld_Stream_Result', SendDe, ResultDE, 5000);
  if ResultDE.Count > 0 then
      DoStatus('server response:%s', [ResultDE.Reader.ReadString]);
  DisposeObject([SendDe, ResultDE]);
end;

procedure TFMXDoubleClientForm.Timer1Timer(Sender: TObject);
begin
  CheckThread;
  client.Progress;
end;

end.
