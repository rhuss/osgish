package org.jmx4perl.osgish;

import org.osgi.framework.*;
import org.osgi.service.log.LogService;
import org.osgi.util.tracker.ServiceTracker;

import javax.management.MBeanRegistration;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;

/**
 * Implementation of a service layer for communication between 'osgish' and the
 * osgi agent bundle.
 *
 * @author roland
 */
public class OsgishService implements OsgishServiceMBean, MBeanRegistration, ServiceListener, BundleListener {

    // remember context for housekeeping
    BundleContext bundleContext;

    // Timestamps for state checks
    private long bundlesLastChanged;
    private long servicesLastChanged;

    // Tracker to be used for the LogService
    private ServiceTracker logTracker;

    // Name under which this MBean is registered
    private static final String OSGISH_SERVICE_NAME = "osgish:type=Service";

    public OsgishService(BundleContext pBundleContext) {

        logTracker = new ServiceTracker(pBundleContext, LogService.class.getName(), null);
        bundlesLastChanged = getCurrentTime();
        servicesLastChanged = getCurrentTime();
        bundleContext = pBundleContext;
    }

    public boolean hasStateChanged(String pWhat, long pTimestamp) {
        if ("bundles".equals(pWhat)) {
            return isYoungerThan(bundlesLastChanged,pTimestamp);
        } else if ("services".equals(pWhat)) {
            return isYoungerThan(servicesLastChanged,pTimestamp);
        }
        return false;
    }

    private boolean isYoungerThan(long pBundlesLastChanged, long pTimestamp) {
        return pBundlesLastChanged >= pTimestamp;
    }

    void log(int level,String message) {
        LogService logService = (LogService) logTracker.getService();
        if (logService != null) {
            logService.log(level,message);
        }
    }


    // =================================================================================
    // Listener interfaces
    public void serviceChanged(ServiceEvent event) {
        servicesLastChanged = getCurrentTime();
    }

    public void bundleChanged(BundleEvent event) {
        bundlesLastChanged = getCurrentTime();
    }

    private long getCurrentTime() {
        return System.currentTimeMillis() / 1000;
    }


    // =================================================================================
    // MBeanRegistration

    public ObjectName preRegister(MBeanServer pMBeanServer, ObjectName pObjectName)
            throws MalformedObjectNameException {
        // We are providing our own name
        return new ObjectName(OSGISH_SERVICE_NAME);
    }

    public void postRegister(Boolean pBoolean) {
        bundleContext.addBundleListener(this);
        bundleContext.addServiceListener(this);
        logTracker.open();
        log(LogService.LOG_DEBUG,"Registered " + OSGISH_SERVICE_NAME);
    }

    public void preDeregister()  {
        bundleContext.removeBundleListener(this);
        bundleContext.removeServiceListener(this);
        log(LogService.LOG_DEBUG,"Unregistered " + OSGISH_SERVICE_NAME);
        logTracker.close();
    }

    public void postDeregister() {
    }


}
