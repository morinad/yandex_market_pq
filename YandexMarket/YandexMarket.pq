// This file contains your Data Connector logic
section YandexMarket;

[DataSource.Kind="YandexMarket", Publish="YandexMarket.Publish"]
shared YandexMarket.Data = Value.ReplaceType(YandexMarket.Func, FuncType);

FuncType = type function (
      
    campaign  as (type text meta 
    [ 
        Documentation.FieldCaption = "ID кампании (для заказов) / ID кабинета (для товаров):",
        Documentation.SampleValues = {"12345678"}
    ]),
     
        
    reportType as (type text meta 
    [
        Documentation.FieldCaption = "Тип отчёта:",
        Documentation.AllowedValues = {"orders", "products"}
    ])

    )
    as table meta [
        Documentation.Name = "Забираем данные из Яндекс.Маркета",
        Documentation.LongDescription =  "",
        Documentation.Examples = {
        [
            Description = "Сылка на получение токена Маркета:",
            Code = "https://oauth.yandex.ru/authorize?response_type=token&client_id=19fc862db7c6454991393f447c2ba58b&redirect_uri=https://oauth.yandex.ru/verification_code",
            Result = "Токен"
        ]
        }
    ];


YandexMarket.Func =(campaign as text, reportType as text)=>
let
res = if reportType="products" then getOfferMappings(campaign, Extension.CurrentCredential()[Key]) else getOrdersStats(campaign, Extension.CurrentCredential()[Key])
in res;



getOfferMappingsData = (businessId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( Json.Document(Text.ToBinary("{}"))),
web = Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "businesses/" & businessId & "/offer-mappings", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]),
result = Json.Document(web),
    result1 = result[result],
    offerMappings = result1[offerMappings],
    #"Преобразовано в таблицу" = Table.FromList(offerMappings, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Развернутый элемент Column1" = Table.ExpandRecordColumn(#"Преобразовано в таблицу", "Column1", {"offer", "mapping"}, {"offer", "mapping"})
in   #"Развернутый элемент Column1";


getOfferMappingsNextPageToken = (businessId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( Json.Document(Text.ToBinary("{}"))),
web = Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "businesses/" & businessId & "/offer-mappings", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]),
result = Json.Document(web),
    result1 = result[result],
    paging = result1[paging],
    nextPageTokenD = paging[nextPageToken]
in   nextPageTokenD;


getOfferMappings= (businessId as text, token as text)=>
let
tokenList = List.FirstN(List.Generate(()=> "", each _ <> null, each  try getOfferMappingsNextPageToken( businessId, token,  _ ) otherwise null),1000),
#"Преобразовано в таблицу" = Table.FromList(tokenList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page_token"}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Переименованные столбцы", "data", each try getOfferMappingsData(businessId, token,[page_token] ) otherwise null ),
    #"Строки с примененным фильтром" = Table.SelectRows(#"Добавлен пользовательский объект", each ([data] <> null)),
#"Развернутый элемент data" = Table.ExpandListColumn(#"Строки с примененным фильтром", "data"),
#"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page_token"}),
    #"Развернутый элемент data1" = Table.ExpandRecordColumn(#"Удаленные столбцы", "data", {"offer", "mapping"}, {"offer", "mapping"})
in  #"Развернутый элемент data1";


getOrdersStatsData = (campaignId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( Json.Document(Text.ToBinary("{}"))),
web = Function.InvokeAfter(()=> Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns/" & campaignId & "/stats/orders", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]), #duration(0,0,0,0.1)),
result = Json.Document(web),
    result1 = result[result],
    orders = result1[orders],
    #"Преобразовано в таблицу" = Table.FromList(orders, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "data"}})
in   #"Переименованные столбцы";
    

getOrdersStatsNextPageToken = (campaignId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( Json.Document(Text.ToBinary("{}"))),
web = Function.InvokeAfter(()=>Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns/" & campaignId & "/stats/orders", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]), #duration(0,0,0,0.1)),
result = Json.Document(web),
    result1 = result[result],
    paging = result1[paging],
    nextPageTokenD = paging[nextPageToken]
in   nextPageTokenD;


getOrdersStats = (campaignId as text, token as text)=>
let
tokenList = List.FirstN(List.Generate(()=> "", each _ <> null, each  try getOrdersStatsNextPageToken( campaignId, token,  _ ) otherwise null),1000),
#"Преобразовано в таблицу" = Table.FromList(tokenList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page_token"}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Переименованные столбцы", "data", each try getOrdersStatsData(campaignId, token,[page_token] ) otherwise null ),
    #"Строки с примененным фильтром" = Table.SelectRows(#"Добавлен пользовательский объект", each ([data] <> null)),
#"Развернутый элемент data" = Table.ExpandListColumn(#"Строки с примененным фильтром", "data"),
    #"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page_token"}),
    #"Развернутый элемент data1" = Table.ExpandRecordColumn(#"Удаленные столбцы", "data", {"data"}, {"data"})
in  #"Развернутый элемент data1";


YandexMarket = [
    TestConnection = (dataSourcePath) => 
        { "YandexMarket.Data", 
        Json.Document(dataSourcePath)[campaign], 
        Json.Document(dataSourcePath)[reportType]
        },
    
    Authentication = [
        
         Key = []
   
    ],
    Label = "YandexMarket Connection"
];



YandexMarket.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "YandexMarket Connector", "YandexMarket Help" },
    LearnMoreUrl = "",
    SourceImage = YandexMarket.Icons,
    SourceTypeImage = YandexMarket.Icons
];



YandexMarket.Icons = [
    Icon16 = { Extension.Contents("YandexMarket16.png"), Extension.Contents("YandexMarket20.png"), Extension.Contents("YandexMarket24.png"), Extension.Contents("YandexMarket32.png") },
    Icon32 = { Extension.Contents("YandexMarket32.png"), Extension.Contents("YandexMarket40.png"), Extension.Contents("YandexMarket48.png"), Extension.Contents("YandexMarket64.png") }
];