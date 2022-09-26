// This file contains your Data Connector logic
section YandexMarket;

[DataSource.Kind="YandexMarket", Publish="YandexMarket.Publish"]
shared YandexMarket.Data = Value.ReplaceType(YandexMarket.Func, FuncType);

FuncType = type function (
      
    campaign  as (type text meta 
    [
        Documentation.FieldCaption = "ID кампании:",
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
res = if reportType="products" then getProducts(campaign, Extension.CurrentCredential()[Key]) else getOrders(campaign, Extension.CurrentCredential()[Key])
in res;


getProductsPageToken = (campaign as text, token as text, pageToken as text)=>
let
headers=[#"Content-Type" = "application/json", #"Authorization" = "OAuth oauth_token="""& token &""", oauth_client_id=""19fc862db7c6454991393f447c2ba58b"""],
querydata = [ page_token = pageToken ],
web = Web.Contents("https://api.partner.market.yandex.ru", [RelativePath = "v2/campaigns/"& campaign &"/offer-mapping-entries.json", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata]),
result = Json.Document(web),
result1 = result[result],
paging = result1[paging],
nextPageToken = try paging[nextPageToken] otherwise null
in nextPageToken;


getProducts = (campaign as text, token as text)=>
let
tokenList = List.FirstN(List.Generate(()=> "", each _ <> null, each getProductsPageToken( campaign, token,  _ )),100),
#"Преобразовано в таблицу" = Table.FromList(tokenList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page_token"}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Переименованные столбцы", "data", each getProductsData(campaign, token,[page_token] )),
#"Развернутый элемент data" = Table.ExpandListColumn(#"Добавлен пользовательский объект", "data"),
#"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page_token"})
in #"Удаленные столбцы";


getOrders = (campaign as text, token as text)=>
let
pageList = {1..getOrdersPageCounts(token, campaign)},
#"Преобразовано в таблицу" = Table.FromList(pageList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Переименованные столбцы" = Table.RenameColumns(#"Преобразовано в таблицу",{{"Column1", "page"}}),
#"Измененный тип" = Table.TransformColumnTypes(#"Переименованные столбцы",{{"page", type text}}),
#"Добавлен пользовательский объект" = Table.AddColumn(#"Измененный тип", "data", each Table.FromList(Json.Document(Web.Contents("https://api.partner.market.yandex.ru", [RelativePath = "v2/campaigns/"& campaign &"/orders.json", Headers = [#"Content-Type" = "application/json", #"Authorization" = "OAuth oauth_token="""& token &""", oauth_client_id=""19fc862db7c6454991393f447c2ba58b"""], ManualStatusHandling = {404, 400}, Query =[ page = [page] ]]))[orders], Splitter.SplitByNothing(), null, null, ExtraValues.Error)),
#"Развернутый элемент data" = Table.ExpandTableColumn(#"Добавлен пользовательский объект", "data", {"Column1"}, {"data"}),
#"Удаленные столбцы" = Table.RemoveColumns(#"Развернутый элемент data",{"page"})
in #"Удаленные столбцы";


getOrdersPageCounts=(token as text, campaign as text) =>
let
page = "1",
headers=[#"Content-Type" = "application/json", #"Authorization" = "OAuth oauth_token="""& token &""", oauth_client_id=""19fc862db7c6454991393f447c2ba58b"""],
querydata = [ page = page ],
web = Web.Contents("https://api.partner.market.yandex.ru", [RelativePath = "v2/campaigns/"& campaign &"/orders.json", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata]),
result = Json.Document(web),
pager = result[pager],
pagesCount = Number.From(pager[pagesCount])
in pagesCount;


getProductsData = (campaign, token, pageToken)=>
let
headers=[#"Content-Type" = "application/json", #"Authorization" = "OAuth oauth_token="""& token &""", oauth_client_id=""19fc862db7c6454991393f447c2ba58b"""],
querydata = [ page_token = pageToken ],
web = Web.Contents("https://api.partner.market.yandex.ru", [RelativePath = "v2/campaigns/"& campaign &"/offer-mapping-entries.json", Headers = headers, ManualStatusHandling = {404, 400}, Query =querydata]),
result = Json.Document(web),
result1 = result[result],
offerMappingEntries = result1[offerMappingEntries]
in offerMappingEntries;



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