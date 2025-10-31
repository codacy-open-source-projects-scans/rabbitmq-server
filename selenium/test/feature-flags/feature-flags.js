const { By, Key, until, Builder } = require('selenium-webdriver')
require('chromedriver')
const assert = require('assert')
const { buildDriver, goToHome, captureScreensFor, teardown, findTableRow, delay } = require('../utils')

const LoginPage = require('../pageobjects/LoginPage')
const OverviewPage = require('../pageobjects/OverviewPage')
const AdminTab = require('../pageobjects/AdminTab')
const FeatureFlagsAdminTab = require('../pageobjects/FeatureFlagsAdminTab')

describe('Feature flags in Admin tab', function () {
  let login
  let overview
  let ffTab
  let captureScreen

  before(async function () {
    driver = buildDriver()
    await goToHome(driver)
    login = new LoginPage(driver)
    overview = new OverviewPage(driver)
    adminTab = new AdminTab(driver)
    ffTab = new FeatureFlagsAdminTab(driver)
    captureScreen = captureScreensFor(driver, __filename)

    await login.login('guest', 'guest')
    if (!await overview.isLoaded()) {
      throw new Error('Failed to login')
    }
    await overview.selectRefreshOption("Do not refresh")
  })

  it('it has at least one feature flag', async function () {
    await overview.clickOnAdminTab()
    await adminTab.clickOnFeatureFlags()
    let ffTable = await ffTab.getAll()
    assert(ffTable.length > 0)
  })
  it('it has khepri_db feature flag', async function () {
    await overview.clickOnAdminTab()
    await adminTab.clickOnFeatureFlags()
    let ffTable = await ffTab.getAll()
    assert(findTableRow(ffTable, function(row) {
        return row[0] === 'khepri_db'
    }))
    let state = await ffTab.getState('khepri_db')
    assert(await state.isSelected())  
  })


  after(async function () {
    await teardown(driver, this, captureScreen)
  })
})
