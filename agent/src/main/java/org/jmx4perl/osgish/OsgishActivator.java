package org.jmx4perl.osgish;

import org.apache.aries.jmx.Activator;
import org.jmx4perl.osgi.J4pActivator;
import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;
import org.osgi.framework.ServiceRegistration;

import javax.management.MBeanServer;
import java.lang.management.ManagementFactory;

/**
 * Activator for activation the embedded j4p agent as well
 * as the Aries JMX bundle.
 *
 * @author roland
 * @since Jan 9, 2010
 */
public class OsgishActivator implements BundleActivator {

    J4pActivator j4pActivator;
    Activator ariesActivator;

    public OsgishActivator() {
        j4pActivator = new J4pActivator();
        ariesActivator = new Activator();
    }

    public void start(BundleContext context) throws Exception {
        j4pActivator.start(context);
        registerMBeanServerAsService(context);
        ariesActivator.start(context);
    }

    public void stop(BundleContext context) throws Exception {
        ariesActivator.stop(context);
        j4pActivator.stop(context);
        // Service will be automatically unregistered
    }


    private void registerMBeanServerAsService(BundleContext pContext) {
        ServiceReference mBeanServerRef = pContext.getServiceReference(MBeanServer.class.getCanonicalName());
        if (mBeanServerRef == null) {
            // Register a MBeanServer as service
            // Really the platform MBeanServer ? or a new MBeanServer ?
            pContext.registerService(MBeanServer.class.getCanonicalName(), getMBeanServer(), null);
        } else {
            MBeanServer mBeanServer = (MBeanServer) pContext.getService(mBeanServerRef);
            pContext.ungetService(mBeanServerRef);
            if (mBeanServer == null) {
                pContext.registerService(MBeanServer.class.getCanonicalName(), getMBeanServer(), null);
            }
        }
    }

    private MBeanServer getMBeanServer() {
        return ManagementFactory.getPlatformMBeanServer();
    }


}
