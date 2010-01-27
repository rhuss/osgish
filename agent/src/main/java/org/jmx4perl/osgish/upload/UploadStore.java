package org.jmx4perl.osgish.upload;

import javax.management.MBeanRegistration;
import javax.management.MBeanServer;
import javax.management.ObjectName;
import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * Implemententaion of an upload store.
 *
 * @author roland
 * @since Jan 27, 2010
 */
public class UploadStore implements UploadStoreMBean, MBeanRegistration {

    File dataDir;

    // Name to be used for registering as MBean
    private static final String UPLOAD_STORE_NAME = "osgish:type=Upload";

    public UploadStore(File pDataDir) {
        dataDir = pDataDir;
        if (!dataDir.exists()) {
            throw new IllegalArgumentException("No data directory " + dataDir.getAbsolutePath() + " found");
        }
        if (!dataDir.isDirectory()) {
            throw new IllegalArgumentException(dataDir.getAbsolutePath() + " is not a directory");
        }
    }

    public Map listUploadDirectory() {
        File files[] = dataDir.listFiles();
        Map<String,File> ret = new HashMap<String,File>();
        for (File file : files) {
            ret.put(file.getName(),file);
        }
        return ret;
    }

    public void deleteFile(String pFilename) {
        if (pFilename == null) {
            throw new IllegalArgumentException("No filename given");
        }
        if (pFilename.startsWith("/")) {
            throw new IllegalArgumentException("Path '" + pFilename + "' must not be an absolute path");
        }
        File dir = dataDir;
        String parts[] = pFilename.split("/");
        String last = parts[parts.length-1];
        for (int i = 0;i<parts.length - 1;i++) {
            dir = new File(dir,parts[i]);
            if (!dir.isDirectory()) {
                throw new IllegalArgumentException("'" + dir.getPath() + "' is not a directory");
            }
        }
        File file = new File(dir,last);
        if (!file.exists()) {
            throw new IllegalArgumentException("'" + file.getPath() + "' does not exist");
        }
        if (!file.delete()) {
            throw new IllegalArgumentException("Cannot delet file '" + file.getPath() + "'");
        }
    }

    public ObjectName preRegister(MBeanServer server, ObjectName name) throws Exception {
        // We are providing our own name
        return new ObjectName(UPLOAD_STORE_NAME);
    }

    public void postRegister(Boolean registrationDone) {
    }

    public void preDeregister() throws Exception {
    }

    public void postDeregister() {
    }
}
