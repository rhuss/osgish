package org.jmx4perl.osgish;

import org.apache.aries.jmx.Activator;
import org.jmx4perl.osgi.J4pActivator;
import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;
import org.osgi.service.log.LogService;
import org.osgi.util.tracker.ServiceTracker;

import javax.management.*;
import java.lang.management.ManagementFactory;

/**
 * Activator for activation the embedded j4p agent as well
 * as the Aries JMX bundle. So it's an aggregat activator.
 *
 * It also registers an (arbitrary) MBeanServer if not already
 * an MBeanServer is registered. This service is required by Aries JMX.

 * @author roland
 * @since Jan 9, 2010
 */
public class OsgishActivator implements BundleActivator {

    J4pActivator j4pActivator;
    Activator ariesActivator;

    // Name of the servie MBean
    private ObjectName serviceMBeanName;

    // MBeanServer where we registered our MBeans
    private MBeanServer mBeanServer;


    public OsgishActivator() {
        j4pActivator = new J4pActivator();
        ariesActivator = new Activator();
    }

    public void start(BundleContext pContext) throws Exception {
        j4pActivator.start(pContext);
        registerMBeanServerAsService(pContext);
        registerOsgiServiceMBean(pContext);
        ariesActivator.start(pContext);
    }

    public void stop(BundleContext pContext) throws Exception {
        ariesActivator.stop(pContext);
        unregisterOsgiServiceMBean();
        // Service will be automatically unregistered (can this be done explicitely ?)
        j4pActivator.stop(pContext);
    }

    private void registerMBeanServerAsService(BundleContext pContext) {
        ServiceReference mBeanServerRef = pContext.getServiceReference(MBeanServer.class.getCanonicalName());
        if (mBeanServerRef == null) {
            // Register a MBeanServer as service
            mBeanServer = getMBeanServer();
            pContext.registerService(MBeanServer.class.getCanonicalName(), mBeanServer, null);
        } else {
            boolean serviceFound = true;
            try {
                mBeanServer = (MBeanServer) pContext.getService(mBeanServerRef);
                if (mBeanServer == null) {
                    mBeanServer = getMBeanServer();
                    pContext.registerService(MBeanServer.class.getCanonicalName(), mBeanServer, null);
                    serviceFound = false;
                }
            } finally {
                if (mBeanServerRef != null && serviceFound) {
                    pContext.ungetService(mBeanServerRef);
                }
            }
        }
    }

    // Register our own service for MBeanServer at use.
    private void registerOsgiServiceMBean(BundleContext pBundleContext)
            throws MBeanRegistrationException, InstanceAlreadyExistsException, NotCompliantMBeanException {
        OsgishService service = new OsgishService(pBundleContext);
        serviceMBeanName = mBeanServer.registerMBean(service,null).getObjectName();
        System.out.println(">>>>>>>>>>> osgish: Registering " + serviceMBeanName + " to " + mBeanServer);
    }

    // Un-Register MBean. Since we want to use the same MBeanSever as during registration
    // We kept a reference to the mbean server
    private void unregisterOsgiServiceMBean() throws InstanceNotFoundException, MBeanRegistrationException {
        if (mBeanServer != null) {
            mBeanServer.unregisterMBean(serviceMBeanName);
            mBeanServer = null;
            System.out.println(">>>>>>>>>>> osgish: Un-Registering " + serviceMBeanName + " from " + mBeanServer);
        }
    }

    private MBeanServer getMBeanServer() {
        // Using this one, which is always there. No security in mind, though.
        // Alternative: Use a new MBeanServer() ?
        return ManagementFactory.getPlatformMBeanServer();
    }




}
