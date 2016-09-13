Banking  = require 'banking'

module.exports =
  spreadsheetId: '1UVPZEttwS8SdRpJAU9u_2dR12NRYKcWWJoQ6HHaVCNQ'
  banks: [
    {
      name: 'BofA'
      object: Banking(
          fid:      5959
          fidOrg:   'HAN'
          url:      'https://eftx.bankofamerica.com/eftxweb/access.ofx'
          bankId:   '121000358'
          user:     'vasya'
          password: 'kewlhax0r'
          accId:    '000999999999'
          accType:  'CHECKING'
          ofxVer:   103
          app:      'QWIN'
          appVer:   '2300'
        )
    },{
      name: 'AmEx'
      object: Banking(
          fid:      3101
          fidOrg:   'AMEX'
          url:      'https://online.americanexpress.com/myca/ofxdl/desktop/desktopDownload.do?request_type=nl_ofxdownload'
          user:     'vasya'
          password: 'el1tErUlEz'
          accId:    '379705559226992'
          accType:  'CREDITCARD'
          ofxVer:   103
          app:      'QWIN'
          appVer:   '1700'
        )
    },{
      name: 'Citibank'
      object: Banking(
          fid:      24909
          fidOrg:   'Citigroup'
          url:      'https://www.accountonline.com/cards/svc/CitiOfxManager.do'
          user:     'vasyapupkin'
          password: 'w1feKn0wZ'
          accId:    '4100777776666633'
          accType:  'CREDITCARD'
          ofxVer:   103
          app:      'QWIN'
          appVer:   '1700'
        )
    }
  ]

