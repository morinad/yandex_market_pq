// This file contains your Data Connector logic
section YandexMarket;

[DataSource.Kind="YandexMarket", Publish="YandexMarket.Publish"]
shared YandexMarket.Data = Value.ReplaceType(YandexMarket.Func, FuncType);

FuncType = type function (
      
    campaign  as (type text meta 
    [ 
        Documentation.FieldCaption = "ID кампании(order,stocks)/ID кабинета(mapp,camp):",
        Documentation.SampleValues = {"12345678"}
    ]),
    reportType as (type text meta 
    [
        Documentation.FieldCaption = "Тип отчёта:",
        Documentation.AllowedValues = {"orders", "stocks","mappings", "campaigns"}
    ]),
       date1 as (type nullable text meta 
    [
        Documentation.FieldCaption = "Дата начала:",
        Documentation.SampleValues = {"2025-02-28"}
    ]),

       date2 as (type nullable text meta 
    [
        Documentation.FieldCaption = "Дата окончания:",
        Documentation.SampleValues = {"yesterday"}
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



YandexMarket.Func =(campaign as text, reportType as text, date1 as nullable text, date2 as nullable text)=>
let
res = 
if reportType="mappings" then getOfferMappings(campaign, Extension.CurrentCredential()[Key])
else if reportType="stocks" then getStocks(campaign, Extension.CurrentCredential()[Key]) 
else if reportType="campaigns" then getCampaigns(campaign, Extension.CurrentCredential()[Key]) 
else if reportType="orders" then getOrders(campaign, Extension.CurrentCredential()[Key], dateFunc(date1),dateFunc(date2)) 
else null
in res;


dateFunc = (dat)=>
        if dat = null then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
        else if dat = "yesterday" then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
        else if dat = "today" then Date.ToText(Date.From(DateTime.LocalNow()),"yyyy-MM-dd")
        else if (try Number.From(Text.BeforeDelimiter(dat,"daysAgo")) otherwise 0) >0 then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()),-1*Number.From(Text.BeforeDelimiter(dat,"daysAgo"))),"yyyy-MM-dd") 
        else dat;


getCampaigns = 
(businessId as text, token as text)=>
let
headers=[#"Authorization" = "Bearer " & token],
web = Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns",Headers = headers, ManualStatusHandling = {404, 400}]),
result = Json.Document(web),
    campaigns = result[campaigns],
    #"Преобразовано в таблицу" = Table.FromList(campaigns, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Развернутый элемент Column1" = try Table.ExpandRecordColumn(#"Преобразовано в таблицу", "Column1", {"domain", "id", "clientId", "business", "placementType"}, {"domain", "id", "clientId", "business", "placementType"}) otherwise #"Преобразовано в таблицу"
in
    #"Развернутый элемент Column1";



getOfferMappings=(businessId as text, token as text)=>
let
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
in
    #"Развернутый элемент Column1",
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
in
    nextPageTokenD,
tokenList = List.FirstN(List.Generate(()=> "", each _ <> null, each  try getOfferMappingsNextPageToken( businessId, token,  _ ) otherwise null),1000),
#"Преобразовано в таблицу" = Table.FromList(tokenList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page_token"}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Переименованные столбцы", "data", each try getOfferMappingsData(businessId, token,[page_token] ) otherwise null ),
    #"Строки с примененным фильтром" = Table.SelectRows(#"Добавлен пользовательский объект", each ([data] <> null)),
#"Развернутый элемент data" = Table.ExpandListColumn(#"Строки с примененным фильтром", "data"),
#"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page_token"}),
    #"Развернутый элемент data1" = Table.ExpandRecordColumn(#"Удаленные столбцы", "data", {"offer", "mapping"}, {"offer", "mapping"})
in  #"Развернутый элемент data1";


getOrders = (campaignId as text, token as text, date1 as text, date2 as text)=>
let
getOrdersStatsData = (campaignId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue([dateFrom = dateFunc(date1), dateTo = dateFunc(date2)]),
web = Function.InvokeAfter(()=> Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns/" & campaignId & "/stats/orders", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]), #duration(0,0,0,0.1)),
result = Json.Document(web),
    result1 = result[result],
    orders = result1[orders],
    #"Преобразовано в таблицу" = Table.FromList(orders, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "data"}})
in
    #"Переименованные столбцы",
getOrdersStatsNextPageToken = (campaignId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( [dateFrom = dateFunc(date1), dateTo = dateFunc(date2)] ),
web = Function.InvokeAfter(()=>Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns/" & campaignId & "/stats/orders", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]), #duration(0,0,0,0.1)),
result = Json.Document(web),
    result1 = result[result],
    paging = result1[paging],
    nextPageTokenD = paging[nextPageToken]
in
    nextPageTokenD,
tokenList = List.FirstN(List.Generate(()=> "", each _ <> null, each  try getOrdersStatsNextPageToken( campaignId, token,  _ ) otherwise null),1000),
#"Преобразовано в таблицу" = Table.FromList(tokenList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page_token"}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Переименованные столбцы", "data", each try getOrdersStatsData(campaignId, token,[page_token] ) otherwise null ),
    #"Строки с примененным фильтром" = Table.SelectRows(#"Добавлен пользовательский объект", each ([data] <> null)),
#"Развернутый элемент data" = Table.ExpandListColumn(#"Строки с примененным фильтром", "data"),
    #"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page_token"}),
    #"Развернутый элемент data1" = Table.ExpandRecordColumn(#"Удаленные столбцы", "data", {"data"}, {"data"})
in
    #"Развернутый элемент data1";


getStocks = (campaignId as text, token as text)=>
let
getStocksData = (campaignId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( [ ]),
web = Function.InvokeAfter(()=> Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns/" & campaignId & "/offers/stocks", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]), #duration(0,0,0,0.1)),
result = Json.Document(web),
    result1 = result[result],
    warehouses = result1[warehouses],
    #"Преобразовано в таблицу1" = Table.FromList(warehouses, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Развернутый элемент Column2" = Table.ExpandRecordColumn(#"Преобразовано в таблицу1", "Column1", {"warehouseId", "offers"}, {"warehouseId", "offers"}),
    #"Развернутый элемент offers" = Table.ExpandListColumn(#"Развернутый элемент Column2", "offers"),
    #"Развернутый элемент offers1" = Table.ExpandRecordColumn(#"Развернутый элемент offers", "offers", {"offerId", "stocks", "updatedAt"}, {"offerId", "stocks", "updatedAt"}),
    #"Развернутый элемент stocks" = Table.ExpandListColumn(#"Развернутый элемент offers1", "stocks"),
    #"Развернутый элемент stocks1" = Table.ExpandRecordColumn(#"Развернутый элемент stocks", "stocks", {"type", "count"}, {"type", "count"})
in
    #"Развернутый элемент stocks1",
getStocksNextPageToken = (campaignId as text, token as text, nextPageToken as  text)=>
let
headers=[#"Authorization" = "Bearer " & token ],
querydata = [#"limit" = "200", #"page_token" = nextPageToken],
jsondata = Json.FromValue( [ ]),
web = Function.InvokeAfter(()=>Web.Contents("https://api.partner.market.yandex.ru/", [RelativePath = "campaigns/" & campaignId & "/offers/stocks", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata, Content = jsondata]), #duration(0,0,0,0.1)),
result = Json.Document(web),
    result1 = result[result],
    paging = result1[paging],
    nextPageTokenD = paging[nextPageToken]
in
    nextPageTokenD,
tokenList = List.FirstN(List.Generate(()=> "", each _ <> null, each  try getStocksNextPageToken( campaignId, token,  _ ) otherwise null),1000),
#"Преобразовано в таблицу" = Table.FromList(tokenList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page_token"}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Переименованные столбцы", "data", each try getStocksData(campaignId, token,[page_token] ) otherwise null ),
#"Строки с примененным фильтром" = Table.SelectRows(#"Добавлен пользовательский объект", each ([data] <> null)),
#"Развернутый элемент data" = Table.ExpandListColumn(#"Строки с примененным фильтром", "data"),
#"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page_token"}),
#"Развернутый элемент data1" = Table.ExpandRecordColumn(#"Удаленные столбцы", "data", {"offerId", "stocks", "updatedAt"}, {"offerId", "stocks", "updatedAt"})
in    #"Удаленные столбцы";


YandexMarket = [
    TestConnection = (dataSourcePath) => 
        { "YandexMarket.Data", 
        Json.Document(dataSourcePath)[campaign], 
        Json.Document(dataSourcePath)[reportType],
        Json.Document(dataSourcePath)[date1]?,
        Json.Document(dataSourcePath)[date2]?
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